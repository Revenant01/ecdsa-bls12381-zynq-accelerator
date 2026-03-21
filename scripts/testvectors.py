import helpers
import HW
import SW
import curves
import sys

operation = 0
seed = "random"

print ("TEST VECTOR GENERATOR FOR DDP\n")

if len(sys.argv) in [2,3,4]:
  if str(sys.argv[1]) == "adder":           operation = 1
  if str(sys.argv[1]) == "subtractor":      operation = 2
  if str(sys.argv[1]) == "multiplication":  operation = 3
  if str(sys.argv[1]) == "EC_add":          operation = 4
  if str(sys.argv[1]) == "EC_mult":         operation = 5
  if str(sys.argv[1]) == "ECDSA_verify":    operation = 6


if len(sys.argv) in [3,4]:
  print ("Seed is: ", sys.argv[2], "\n")
  seed = sys.argv[2]
  helpers.setSeed(sys.argv[2])

if len(sys.argv) == 4:
  if (sys.argv[3].upper() == "NOWRITE"):
    print ("NOT WRITING TO TESTVECTOR.C FILE \n")

#####################################################

if operation == 0:
  print ("You should use this script by passing an argument like:")
  print (" $ python testvectors.py adder")
  print (" $ python testvectors.py subtractor")
  print (" $ python testvectors.py multiplication")
  print (" $ python testvectors.py EC_add")
  print (" $ python testvectors.py EC_mult")
  print (" $ python testvectors.py ECDSA_verify")
  print ("")
  print ("You can also set a seed for randomness to work")
  print ("with the same testvectors at each execution:")
  print (" $ python testvectors.py ECDSA_verify 2025")
  print ("")
  print ("To NOT write to testvector.c file automatically: ")
  print (" $ python testvectors.py ECDSA_verify 2025 nowrite")
  print ("")

#####################################################

if operation == 1:
  print ("Test Vector for Adder\n")

  A = helpers.getRandomInt(384)
  B = helpers.getRandomInt(384)
  C = HW.MultiPrecisionAddSub_384(A,B,"add")

  print ("A                = ", hex(A))           # 1027-bits
  print ("B                = ", hex(B))           # 1027-bits
  print ("A + B            = ", hex(C))           # 1028-bits

#####################################################

if operation == 2:
  print ("Test Vector for Multi Precision Subtractor\n")

  A = helpers.getRandomInt(384)
  B = helpers.getRandomInt(384)
  C = HW.MultiPrecisionAddSub_384(A,B,"subtract")

  print ("A                = ", hex(A))           # 1027-bits
  print ("B                = ", hex(B))           # 1027-bits
  print ("A - B            = ", hex(C))           # 1028-bits

#####################################################

if operation == 3:

  print ("Test Vector for Windowed Montgomery Multiplication\n")

  M = helpers.getModulus(381)
  A = helpers.getRandomInt(381) % M
  B = helpers.getRandomInt(381) % M

  C = HW.MontMul(A, B, M)
  D = SW.MontMul(A, B, M)

  e = (C - D)
  print(f"in_a        <= 381'h{A:0096x};")  
  print(f"in_b        <= 381'h{B:0096x};")  
  print(f"in_m        <= 381'h{M:0096x};")  
  print(f"expected HW <= 381'h{C:0096x};")  # Expected result
  print(f"expected SW <= 381'h{D:0096x};")  # Expected result

#####################################################

if operation == 4:

  print ("Test Vector for Elliptic Curve Addition\n")
  G = helpers.affineToProjective(curves.G)  # Use G from curves module
  #Making 2 points that lie on the elliptic curve
  s1 = helpers.getRandomInt(255) % curves.groupOrder
  s2 = helpers.getRandomInt(255) % curves.groupOrder
  Point1 = SW.EC_scalar_mult(s1,G)
  Point2 = SW.EC_scalar_mult(s2,G)

  Out_SW = SW.EC_addition(Point1, Point2)

  #HARDWARE (SLOWER BUT SHOULD BE EXACTLY THE SAME)
  Point1HW = HW.EC_scalar_mult(s1,G)
  Point2HW = HW.EC_scalar_mult(s2,G) 
  Out_HW = HW.EC_addition(Point1HW, Point2HW)
  e0 = Out_SW[0] - Out_HW[0]
  e1 = Out_SW[1] - Out_HW[1]
  e2 = Out_SW[2] - Out_HW[2]
  assert(e0 == 0)
  assert(e1 == 0)
  assert(e2 == 0)


  print(f"inM          <= 381'h{curves.q:0096x};\n")
  print(f"inX1         <= 381'h{Point1[0]:0096x};")  
  print(f"inY1         <= 381'h{Point1[1]:0096x};")
  print(f"inZ1         <= 381'h{Point1[2]:0096x};\n")
  print(f"inX2         <= 381'h{Point2[0]:0096x};")  
  print(f"inY2         <= 381'h{Point2[1]:0096x};")
  print(f"inZ2         <= 381'h{Point2[2]:0096x};\n")
  print(f"outX         <= 381'h{Out_SW[0]:0096x};")  
  print(f"outY         <= 381'h{Out_SW[1]:0096x};")
  print(f"outZ         <= 381'h{Out_SW[2]:0096x};")
  



#####################################################
if operation == 5:

  print ("Test Vector for Elliptic Curve Scalar Multiplication\n")
  G = helpers.affineToProjective(curves.G)  # Use G from curves module
  #Making new points that lie on the elliptic curve
  s1 = helpers.getRandomInt(255) % curves.groupOrder
  Point = SW.EC_scalar_mult(s1,G)

  s2 = helpers.getRandomInt(255) % curves.groupOrder
  
  Out_SW = SW.EC_scalar_mult(s2, Point)

  #HARDWARE (SLOWER BUT SHOULD BE EXACTLY THE SAME)
  PointHW = HW.EC_scalar_mult(s1,G)
  Out_HW = HW.EC_scalar_mult(s2, PointHW, verbose=True)
  e0 = Out_SW[0] - Out_HW[0]
  e1 = Out_SW[1] - Out_HW[1]
  e2 = Out_SW[2] - Out_HW[2]
  assert(e0 == 0)
  assert(e1 == 0)
  assert(e2 == 0)



  print(f"381'h{curves.q:0096x},")
  print(f"381'h{Point[0]:0096x},")  
  print(f"381'h{Point[1]:0096x},")
  print(f"381'h{Point[2]:0096x},")
  print(f"255'h{s2:0064x},") 
  print(f"expected_Xr        <= 381'h{Out_SW[0]:0096x};")  
  print(f"expected_Yr        <= 381'h{Out_SW[1]:0096x};")
  print(f"expected_Zr        <= 381'h{Out_SW[2]:0096x};\n")
  




#####################################################

if operation == 6:

  print ("Test Vector for ECDSA verification\n")

  G = helpers.affineToProjective(curves.G)  # Use G from curves module
  private_key = helpers.getRandomInt(255) % curves.groupOrder

  # 2. Compute public key P = p * G
  public_key = SW.EC_scalar_mult(private_key, G)
  # 3. Create message hash (simulate hash with random number < groupOrder)
  message = helpers.getRandomInt(255) % curves.groupOrder

  # 4. Sign the message
  signature = SW.ecdsa_sign(private_key, message)
  K, s = signature

  # 5. Verify the signature
  verify_result = SW.ecdsa_verify(message, signature, public_key)
  valid, C, C_prime, r, Q, L = verify_result
  
  # Get K_X_Modn (r value)
  K_affine = helpers.projectiveToAffine(K)
  K_X_Modn = K_affine[0] % curves.groupOrder
  
  # Compute LHS and RHS for Montgomery comparison (as computed in hardware)
  # Hardware computes: LHS = MontMul(C_z, D_x) and RHS = MontMul(D_z, C_x)
  # MontMul(a, b) = a * b * R^-1 mod q where R = 2^381
  R = 2**381
  R_inv = helpers.Modinv(R, curves.q)
  LHS = (C[2] * C_prime[0] * R_inv) % curves.q  # MontMul(C_z, D_x)
  RHS = (C_prime[2] * C[0] * R_inv) % curves.q  # MontMul(D_z, C_x)
  
  print("\n=== VERILOG TESTBENCH (Copy & Paste Ready) ===")
  print("// Expected outputs")
  print(f"expected_Qx <= 381'h{Q[0]:096x};")
  print(f"expected_Qy <= 381'h{Q[1]:096x};")
  print(f"expected_Qz <= 381'h{Q[2]:096x};")
  print(f"expected_Lx <= 381'h{L[0]:096x};")
  print(f"expected_Ly <= 381'h{L[1]:096x};")
  print(f"expected_Lz <= 381'h{L[2]:096x};")
  print(f"expected_Cx <= 381'h{C[0]:096x};")
  print(f"expected_Cy <= 381'h{C[1]:096x};")
  print(f"expected_Cz <= 381'h{C[2]:096x};")
  print(f"expected_Dx <= 381'h{C_prime[0]:096x};")
  print(f"expected_Dy <= 381'h{C_prime[1]:096x};")
  print(f"expected_Dz <= 381'h{C_prime[2]:096x};")
  print(f"expected_LHS <= 381'h{LHS:096x};  // MontMul(C_z, D_x)")
  print(f"expected_RHS <= 381'h{RHS:096x};  // MontMul(D_z, C_x)")
  print(f"// LHS == RHS: {LHS == RHS} (signature {'VALID' if LHS == RHS else 'INVALID'})")
  print("\n// Test execution")
  print("perform_calc_ecdsa(")
  print(f"    381'h{curves.q:096x},  // p")
  print(f"    381'h{G[0]:096x},  // Gx")
  print(f"    381'h{G[1]:096x},  // Gy")
  print(f"    381'h{G[2]:096x},  // Gz")
  print(f"    255'h{message:064x},  // m")
  print(f"    381'h{K[0]:096x},  // Kx")
  print(f"    381'h{K[1]:096x},  // Ky")
  print(f"    381'h{K[2]:096x},  // Kz")
  print(f"    255'h{s:064x},  // s")
  print(f"    381'h{public_key[0]:096x},  // Px")
  print(f"    381'h{public_key[1]:096x},  // Py")
  print(f"    381'h{public_key[2]:096x},  // Pz")
  print(f"    255'h{K_X_Modn:064x},  // K_X_Modn")
  print("    cycle_count")
  print(");")
  print("=" * 45)
  print(f"\nVerification: {('✅ VALID' if valid else '❌ INVALID')}")
  if len(sys.argv) == 4:
    if (sys.argv[3].upper() != "NOWRITE"):
      helpers.CreateConstants(seed, message, K, s, curves.q, r, public_key, C, C_prime, G, LHS, RHS)
  else:
    helpers.CreateConstants(seed, message, K, s, curves.q, r, public_key, C, C_prime, G, LHS, RHS)

#####################################################
