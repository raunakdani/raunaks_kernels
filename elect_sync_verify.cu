#include <stdio.h>
#include <stdlib.h>

// Verify elect.sync by forcing a *specific* leader lane in each warp and having
// each thread write a marker value into a contiguous output buffer (one slot
// per thread, indexed by global thread id):
//   - The elected leader of warp w writes 500.
//   - Every other thread writes 0.
//
// elect.sync elects the lowest active lane in the membermask. So to make lane w
// the leader of warp w, we pass a membermask with the low w bits cleared
// (0xFFFFFFFF << w); the lowest remaining active lane is then exactly w:
//   warp 0 -> lane 0 leader, warp 1 -> lane 1 leader, ... warp w -> lane w.
//
// After the kernel runs, the host checks each warp's 32-slot region contains a
// single 500 at the expected lane (== warp id) and 0 everywhere else.

#define WARP_SIZE 32

__global__ void elect_sync_verify_kernel(int *d_out) {
    unsigned int tid = blockIdx.x * blockDim.x + threadIdx.x;
    unsigned int warp_id = tid / WARP_SIZE;
    unsigned int lane = threadIdx.x % WARP_SIZE;   // lane index within the warp

    // We want lane == warp_id to be the elected leader of warp w.
    //
    // elect.sync requires that EVERY thread executing it is named in the
    // membermask, and that all named threads are converged/active. The mask
    // 0xFFFFFFFF << warp_id names lanes [warp_id .. 31], so we must guard the
    // instruction so that only those lanes actually execute it. Inside the
    // branch the converged active set is exactly the masked set, which is the
    // well-defined contract for elect.sync. It then elects the lowest active
    // lane — which is exactly lane == warp_id.
    unsigned int member_mask = 0xFFFFFFFFu << warp_id;

    int value = 0;
    if (lane >= warp_id) {
        unsigned int is_leader;
        asm volatile(
            "{\n\t"
            "  .reg .b32 rx;\n\t"             // dummy 32-bit register for elected lane
            "  .reg .pred p;\n\t"             // predicate: true only for the leader
            "  elect.sync rx|p, %1;\n\t"      // elect lowest active lane in member_mask
            "  selp.u32 %0, 1, 0, p;\n\t"     // is_leader = p ? 1 : 0
            "}"
            : "=r"(is_leader)                 // %0
            : "r"(member_mask)                // %1
        );
        if (is_leader) value = 500;
    }

    // Leader writes 500, everyone else writes 0 — contiguous, one slot per thread.
    d_out[tid] = value;
}

int main() {
    const int total_warps = 5;                 // need warp 4 to exist
    const int total_threads = total_warps * WARP_SIZE;

    // ── Allocations ──────────────────────────────────────────────────────────
    int *h_out = (int *)malloc(total_threads * sizeof(int));
    int *d_out = NULL;
    cudaMalloc(&d_out, total_threads * sizeof(int));

    // Sentinel-fill so any unwritten slot is obvious (0xFF bytes -> -1).
    cudaMemset(d_out, 0xFF, total_threads * sizeof(int));

    // ── Launch (single block, one warp per intended leader lane) ─────────────
    elect_sync_verify_kernel<<<1, total_threads>>>(d_out);
    cudaDeviceSynchronize();

    // ── Copy results back ────────────────────────────────────────────────────
    cudaMemcpy(h_out, d_out, total_threads * sizeof(int), cudaMemcpyDeviceToHost);

    // ── Dump the raw buffer ──────────────────────────────────────────────────
    printf("Output buffer (one slot per thread):\n");
    for (int w = 0; w < total_warps; ++w) {
        printf("warp %d:", w);
        for (int l = 0; l < WARP_SIZE; ++l) {
            printf(" %d", h_out[w * WARP_SIZE + l]);
        }
        printf("\n");
    }
    printf("\n");

    // ── Host-side verification ───────────────────────────────────────────────
    // Expected leader lane in warp w is lane w.
    int failures = 0;
    for (int w = 0; w < total_warps; ++w) {
        int expected_leader = w;
        int warp_ok = 1;
        for (int l = 0; l < WARP_SIZE; ++l) {
            int v = h_out[w * WARP_SIZE + l];
            int expected = (l == expected_leader) ? 500 : 0;
            if (v != expected) {
                printf("  [FAIL] warp %d lane %d: got %d, expected %d\n",
                       w, l, v, expected);
                warp_ok = 0;
                failures++;
            }
        }
        if (warp_ok) {
            printf("  [PASS] warp %d leader is lane %d (value 500)\n",
                   w, expected_leader);
        }
    }

    printf("\n==> %s\n", failures == 0 ? "ALL CHECKS PASSED" : "SOME CHECKS FAILED");

    // ── Cleanup ──────────────────────────────────────────────────────────────
    cudaFree(d_out);
    free(h_out);

    return failures == 0 ? 0 : 1;
}
