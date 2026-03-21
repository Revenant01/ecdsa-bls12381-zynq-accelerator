#include <stdint.h>
#include "xil_printf.h"
#include "xil_cache.h"
#include "common.h"

// These variables are defined in the testvector.c
// that is created by the testvector generator python script
extern uint32_t modulus[32],
                message[32],
                G_X[32],
                G_Y[32],
                G_Z[32],
                K_X[32],
                K_Y[32],
                K_Z[32],
                s[32],
                Public_X[32],
                Public_Y[32],
                Public_Z[32],
                K_X_Modn[32],
                C_X[32],
                C_Y[32],
                C_Z[32],
                C_Prime_X[32],
                C_Prime_Y[32],
                C_Prime_Z[32];

// Register indices
#define COMMAND 0
#define STATUS  0

// Status bit masks
#define ISFLAGSET(reg, bit) (((reg) >> (bit)) & 1)

// Data structure for ECDSA input (13 x 381-bit values)
typedef struct {
  uint32_t modulus[32];
  uint32_t message[32];
  uint32_t G_X[32];
  uint32_t G_Y[32];
  uint32_t G_Z[32];
  uint32_t K_X[32];
  uint32_t K_Y[32];
  uint32_t K_Z[32];
  uint32_t s[32];
  uint32_t Public_X[32];
  uint32_t Public_Y[32];
  uint32_t Public_Z[32];
  uint32_t K_X_Modn[32];
} __attribute__((aligned(128))) ecdsa_input_t;

// Data structure for ECDSA output (15 x 381-bit values: Q, L, C, D points + LHS + RHS + valid)
// Order must match Verilog TX: OUT0-2=Q, OUT3-5=L, OUT6-8=C, OUT9-11=D, OUT12=LHS, OUT13=RHS, OUT14=valid
typedef struct {
  uint32_t Q_X[32];      // Q = m*G
  uint32_t Q_Y[32];
  uint32_t Q_Z[32];
  uint32_t L_X[32];      // L = K_X_Modn*P
  uint32_t L_Y[32];
  uint32_t L_Z[32];
  uint32_t C_X[32];      // C = Q + L
  uint32_t C_Y[32];
  uint32_t C_Z[32];
  uint32_t D_X[32];      // D = s*K (C_Prime)
  uint32_t D_Y[32];
  uint32_t D_Z[32];
  uint32_t LHS[32];      // Debug: LHS of comparison (MontMul(C_z, D_x))
  uint32_t RHS[32];      // Debug: RHS of comparison (MontMul(D_z, C_x))
  uint32_t valid[32];    // Signature valid flag
} __attribute__((aligned(128))) ecdsa_output_t;

void print_array_contents(uint32_t* src) {
  int i;
  for (i=32-4; i>=20; i-=4)
    xil_printf("  %08X %08X %08X %08X\n\r",
      (unsigned int)src[i+3], (unsigned int)src[i+2],
      (unsigned int)src[i+1], (unsigned int)src[i]);
}

void print_debug_info(int DEBUG, ecdsa_input_t* input, ecdsa_output_t* output, volatile uint32_t* HWreg) {
  if (!DEBUG) return;

  xil_printf("\n\r--- Debug: Input Data ---\n\r");
  xil_printf("modulus:\n\r"); print_array_contents(input->modulus);
  xil_printf("message:\n\r"); print_array_contents(input->message);
  xil_printf("G_X:\n\r"); print_array_contents(input->G_X);
  xil_printf("G_Y:\n\r"); print_array_contents(input->G_Y);
  xil_printf("G_Z:\n\r"); print_array_contents(input->G_Z);
  xil_printf("K_X:\n\r"); print_array_contents(input->K_X);
  xil_printf("K_Y:\n\r"); print_array_contents(input->K_Y);
  xil_printf("K_Z:\n\r"); print_array_contents(input->K_Z);
  xil_printf("s:\n\r"); print_array_contents(input->s);
  xil_printf("Public_X:\n\r"); print_array_contents(input->Public_X);
  xil_printf("Public_Y:\n\r"); print_array_contents(input->Public_Y);
  xil_printf("Public_Z:\n\r"); print_array_contents(input->Public_Z);
  xil_printf("K_X_Modn:\n\r"); print_array_contents(input->K_X_Modn);

  xil_printf("\n\r--- Debug: Output Data ---\n\r");
  xil_printf("C_X:\n\r"); print_array_contents(output->C_X);
  xil_printf("C_Y:\n\r"); print_array_contents(output->C_Y);
  xil_printf("C_Z:\n\r"); print_array_contents(output->C_Z);
  xil_printf("D_X:\n\r"); print_array_contents(output->D_X);
  xil_printf("D_Y:\n\r"); print_array_contents(output->D_Y);
  xil_printf("D_Z:\n\r"); print_array_contents(output->D_Z);

  xil_printf("\n\r--- Debug: Montgomery Comparison ---\n\r");
  xil_printf("LHS (MontMul(C_z, D_x)):\n\r");
  print_array_contents(output->LHS);
  xil_printf("RHS (MontMul(D_z, C_x)):\n\r");
  print_array_contents(output->RHS);

  xil_printf("\n\r--- Debug: HW Status ---\n\r");
  xil_printf("STATUS: %08X\n\r", (unsigned int)HWreg[STATUS]);
}

int main() {
  init_platform();
  init_performance_counters(0);

  // Set DEBUG = 1 to enable verbose output, 0 for minimal output
  int DEBUG = 0;

  xil_printf("\n\rECDSA Verification (BLS12-381)\n\r");

  // Register file shared with FPGA
  volatile uint32_t* HWreg = (volatile uint32_t*)0x40400000;

  // Create structured input/output data
  ecdsa_input_t input_data;
  ecdsa_output_t output_data;

  // Copy input data from extern arrays to contiguous structure
  for (int i = 0; i < 32; i++) {
    input_data.modulus[i] = modulus[i];
    input_data.message[i] = message[i];
    input_data.G_X[i]     = G_X[i];
    input_data.G_Y[i]     = G_Y[i];
    input_data.G_Z[i]     = G_Z[i];
    input_data.K_X[i]     = K_X[i];
    input_data.K_Y[i]     = K_Y[i];
    input_data.K_Z[i]     = K_Z[i];
    input_data.s[i]       = s[i];
    input_data.Public_X[i] = Public_X[i];
    input_data.Public_Y[i] = Public_Y[i];
    input_data.Public_Z[i] = Public_Z[i];
    input_data.K_X_Modn[i] = K_X_Modn[i];

    // Zero output data
    output_data.Q_X[i] = 0;
    output_data.Q_Y[i] = 0;
    output_data.Q_Z[i] = 0;
    output_data.L_X[i] = 0;
    output_data.L_Y[i] = 0;
    output_data.L_Z[i] = 0;
    output_data.C_X[i] = 0;
    output_data.C_Y[i] = 0;
    output_data.C_Z[i] = 0;
    output_data.D_X[i] = 0;
    output_data.D_Y[i] = 0;
    output_data.D_Z[i] = 0;
    output_data.LHS[i] = 0;
    output_data.RHS[i] = 0;
    output_data.valid[i] = 0;
  }

  // Flush data cache to ensure data is in DDR
  Xil_DCacheFlushRange((UINTPTR)&input_data, sizeof(ecdsa_input_t));
  Xil_DCacheFlushRange((UINTPTR)&output_data, sizeof(ecdsa_output_t));

  // Configure HW addresses
  xil_printf("Configuring HW...\n\r");
  uint32_t rx_start = (uint32_t)&input_data;
  uint32_t tx_start = (uint32_t)&output_data;
  HWreg[1] = rx_start;
  HWreg[2] = tx_start;

  // Start HW transfer
  xil_printf("Starting HW transfer...\n\r");
  START_TIMING
    HWreg[COMMAND] = 0x01;
    while((HWreg[STATUS] & 0x01) == 0);
  STOP_TIMING
  xil_printf("HW transfer complete.\n\r");

  // Invalidate cache before reading results
  Xil_DCacheInvalidateRange((UINTPTR)&output_data, sizeof(ecdsa_output_t));

  // Print debug info if enabled
  print_debug_info(DEBUG, &input_data, &output_data, HWreg);

  // Check LHS == RHS for verification
  int lhs_rhs_match = 1;
  for (int i = 0; i < 32; i++) {
    if (output_data.LHS[i] != output_data.RHS[i]) {
      lhs_rhs_match = 0;
      break;
    }
  }

  // Print result
  if (lhs_rhs_match) {
	xil_printf("LHS = RHS\n\r");
    xil_printf("Result: VALID SIGNATURE\n\r");
  } else {
    xil_printf("Result: INVALID SIGNATURE\n\r");
  }

  HWreg[COMMAND] = 0x00;
  cleanup_platform();

  return 0;
}

