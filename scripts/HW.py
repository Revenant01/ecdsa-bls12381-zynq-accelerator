import helpers
from modularFunct import *
from curves import *
from math import *
import curves


# Here we implement the three functions 
# that we implement in the hardware lab sessions.

# The mongomery multiplication, and exponentiation
# follow the pseudo code given in the slides,
# so that if needed students can debug
# their code by printing the intermediate values.

def MultiPrecisionAddSub_383(A, B, addsub):
    # returns (A + B) mod 2^383 if   addsub == "add"
    #         (A - B) mod 2^383 else
    
    mask383  = 2**383 - 1
    mask384  = 2**384 - 1

    am     = A & mask383
    bm     = B & mask383

    if addsub == "add": 
        r = (am + bm) 
    else:
        r = (am - bm)
    
    return r & mask384

def MultiPrecisionAddSub_384(A, B, addsub):
    # returns (A + B) mod 2^384 if   addsub == "add"
    #         (A - B) mod 2^384 else
    
    mask384  = 2**384 - 1
    mask385  = 2**385 - 1

    am     = A & mask384
    bm     = B & mask384

    if addsub == "add": 
        r = (am + bm) 
    else:
        r = (am - bm)
    
    return r & mask385

def MontMul(A, B, M):
    # Returns (A*B*Modinv(R,M)) mod M
    
    regA  = A
    regB  = B
    regC  = 0
    regM  = M

    for i in range(0,381):
        
        if (regA % 2) == 0  : regC = regC
        else                : regC = MultiPrecisionAddSub_383(regC, regB, "add")
        #print(f"regC = {regC:0096x};\n")
        if (regC % 2) == 0  : regC = regC >> 1
        else                : regC = MultiPrecisionAddSub_383(regC, regM, "add") >> 1
        #print(f"regC = {regC:0096x};\n")
        regA = regA >> 1

    while regC >= regM:
        regC = MultiPrecisionAddSub_383(regC, regM, "sub")
    
    return regC



#######################################################################################################
#                           FASTER ALTERNATIVE BUT HARDER TO IMPLEMENT                                # 
#             THIS IS AN EXTRA TO DO WHEN YOU ARE DONE AND WANT TO MAKE IT FASTER                     #
#        ASK TEACHING ASSITENT FOR MORE INFO (ODD NUMBER OF BITS, PRECOMPUTE 3M AND 3B)               #
#                                 HARDER TO MEET TIMING CONSTRAINT !!!                                # 
#######################################################################################################
def MontMul_2bW(A, B, M):
    # Implements the multiplication with 2-bit windows
    # Returns (A*B*Modinv(R,M)) mod M
    
    WindowSize = 2
    b = 2**WindowSize
    
    regA  = A
    regB  = B
    regC  = 0
    regM  = M

    # reg2B = MultiPrecisionAddSub_1027(regB, regB , "add")
    reg3B = MultiPrecisionAddSub_1027(regB, regB<<1, "add")
    
    # reg2M = MultiPrecisionAddSub_1027(regM, regM , "add")
    reg3M = MultiPrecisionAddSub_1027(regM, regM<<1, "add")

    # Define a multiplexer function
    def ModMux(M, twoM, threeM, Csel, Msel):
        if   (Csel == 0 and Msel == 1) or (Csel == 0 and Msel == 3) : return 0;
        elif (Csel == 1 and Msel == 1) or (Csel == 3 and Msel == 3) : return threeM;
        elif (Csel == 2 and Msel == 1) or (Csel == 2 and Msel == 3) : return twoM;
        elif (Csel == 3 and Msel == 1) or (Csel == 1 and Msel == 3) : return M;

    for i in range(0, 380//WindowSize):
        
        # Decide the conditional addition with the lsb 2-bits of A
        if   (regA % b) == 0:  regC = regC;
        elif (regA % b) == 1:  regC = MultiPrecisionAddSub_1027(regC, regB   , "add")
        elif (regA % b) == 2:  regC = MultiPrecisionAddSub_1027(regC, regB<<1, "add")
        elif (regA % b) == 3:  regC = MultiPrecisionAddSub_1027(regC, reg3B  , "add")
        # Optionally, two additions can be performed to get rid of reg3B
        # elif (regA % b) == 3:  
        #     regC = MultiPrecisionAddSub_1027(regC, regB   , "add")
        #     regC = MultiPrecisionAddSub_1027(regC, regB<<1, "add")

        # Take the lsb 2-bits of C and M as select signals
        C_sel = (regC % b)
        M_sel = (regM % b)

        ModMuxOut = ModMux(regM, regM<<1,  reg3M, C_sel, M_sel)
        #print(f"regC = {regC:0097x};\n")
        regC = MultiPrecisionAddSub_1027(regC, ModMuxOut, "add") // b
        # Optionally, two additions can be performed to get rid of reg3M
        #print(f"regC = {regC:0097x};\n")
        regA = regA >> WindowSize
        #print(f"regC = {regC:0097x};\n")
    #print(f"regC = {regC:0097x};\n")
    if (regA % 2) == 0  : regC = regC
    else                : regC = MultiPrecisionAddSub_383(regC, regB, "add")
    #print(f"regC = {regC:0096x};\n")
    if (regC % 2) == 0  : regC = regC >> 1
    else                : regC = MultiPrecisionAddSub_383(regC, regM, "add") >> 1
    #print(f"regC = {regC:0096x};\n")
    while regC >= regM:
        regC = MultiPrecisionAddSub_1027(regC, regM, "sub")
    #print(f"regC = {regC:0096x};\n")
    return regC

def EC_addition(P,Q):
    R = 2**381
    #stage1
    X1mX2 = MontMul(P[0],Q[0],q)
    #print(f"\nX1mX2       <= 381'h{X1mX2:0096x};") 
    Y1mY2 = MontMul(P[1],Q[1],q)
    #print(f"Y1mY2       <= 381'h{Y1mY2:0096x};") 
    Z1mZ2 = MontMul(P[2],Q[2],q)
    #print(f"Z1mZ2       <= 381'h{Z1mZ2:0096x};") 
    X1plY1 = modularReduction(P[0]+P[1],q)
    #print(f"X1plY1      <= 381'h{X1plY1:0096x};") 
    X2plY2 = modularReduction(Q[0]+Q[1],q)
    #print(f"X2plY2      <= 381'h{X2plY2:0096x};") 
    X1plZ1 = modularReduction(P[0]+P[2],q)
    #print(f"X1plZ1      <= 381'h{X1plZ1:0096x};") 
    X2plZ2 = modularReduction(Q[0]+Q[2],q)
    #print(f"X2plZ2      <= 381'h{X2plZ2:0096x};") 
    Y1plZ1 = modularReduction(P[1]+P[2],q)
    #print(f"Y1plZ1      <= 381'h{Y1plZ1:0096x};") 
    Y2plZ2 = modularReduction(Q[1]+Q[2],q)
    #print(f"Y2plZ2      <= 381'h{Y2plZ2:0096x};") 
    #stage2 
    X1X2plY1Y2 = modularReduction(X1mX2+Y1mY2,q)
    #print(f"X1X2plY1Y2    <= 381'h{X1X2plY1Y2:0096x};") 
    X1X2plZ1Z2 = modularReduction(X1mX2+Z1mZ2,q)
    #print(f"X1X2plZ1Z2    <= 381'h{X1X2plZ1Z2:0096x};") 
    Y1Y2plZ1Z2 = modularReduction(Y1mY2+Z1mZ2,q)
    #print(f"Y1Y2plZ1Z2    <= 381'h{Y1Y2plZ1Z2:0096x};") 
    X1plY1X2plY2 = MontMul(X1plY1,X2plY2,q)
    #print(f"X1plY1X2plY2    <= 381'h{X1plY1X2plY2:0096x};") 
    X1plZ1X2plZ2 = MontMul(X1plZ1,X2plZ2,q)
    #print(f"X1plZ1X2plZ2    <= 381'h{X1plZ1X2plZ2:0096x};")
    Y1plZ1Y2plZ2 = MontMul(Y1plZ1,Y2plZ2,q)
    #print(f"Y1plZ1Y2plZ2    <= 381'h{Y1plZ1Y2plZ2:0096x};")
    #stage3
    #print(f"R*12%q       <= 381'h{R*12%q:0096x};")
    Z1Z2x12 = MontMul(Z1mZ2,R*12%q,q) #12
    #print(f"Z1Z2x12    <= 381'h{Z1Z2x12:0096x};")
    sub1 = modularReduction(X1plY1X2plY2-X1X2plY1Y2,q)
    #print(f"sub1    <= 381'h{sub1:0096x};")
    sub2 = modularReduction(X1plZ1X2plZ2-X1X2plZ1Z2,q)
    #print(f"sub2    <= 381'h{sub2:0096x};")
    sub3 = modularReduction(Y1plZ1Y2plZ2-Y1Y2plZ1Z2,q)
    #print(f"sub3    <= 381'h{sub3:0096x};")
    #stage4
    #print(f"R*3%q    <= 381'h{R*3%q:0096x};")
    X1X2x3 = MontMul(X1mX2,R*3%q, q) #3
    #print(f"X1X2x3    <= 381'h{X1X2x3:0096x};")
    addStage2 = modularReduction(Y1mY2+Z1Z2x12,q)
    #print(f"addStage2    <= 381'h{addStage2:0096x};")
    subStage2 = modularReduction(Y1mY2-Z1Z2x12,q)
    #print(f"subStage2    <= 381'h{subStage2:0096x};")
    sub2x12 = MontMul(sub2,R*12%q,q) #12
    ###############################################################
    # DO YOU REALLY NEED TO DO A MULTIPLICATION                   #
    # EASY TO IMPLEMENT BUT YOU LOSE ON PERFORMANCE               #
    ###############################################################
    #print(f"sub2x12    <= 381'h{sub2x12:0096x};")
    #stage5
    temp1 = MontMul(subStage2,sub1,q)
    #print(f"temp1    <= 381'h{temp1:0096x};")
    temp2 = MontMul(sub2x12,sub3,q)
    #print(f"temp2    <= 381'h{temp2:0096x};")
    temp3 = MontMul(addStage2,subStage2,q)
    #print(f"temp3    <= 381'h{temp3:0096x};")
    temp4 = MontMul(X1X2x3,sub2x12,q)
    #print(f"temp4    <= 381'h{temp4:0096x};")
    temp5 = MontMul(addStage2,sub3,q)
    #print(f"temp5    <= 381'h{temp5:0096x};")
    temp6 = MontMul(X1X2x3,sub1,q)
    #print(f"temp6    <= 381'h{temp6:0096x};")
    #stage6
    resX = modularReduction(temp1-temp2,q)
    #print(f"resX    <= 381'h{resX:0096x};")
    resY = modularReduction(temp3+temp4,q)
    #print(f"resY    <= 381'h{resY:0096x};")
    resZ = modularReduction(temp5+temp6,q)
    #print(f"resZ    <= 381'h{resZ:0096x};")
    #no need to go out of montgomery
    return(resX,resY,resZ)

def EC_scalar_mult(s, P, verbose=False):
    """
    :param s: Integer scalar (e.g., 255-bit)
    :param P: EC point (projective XYZ)
    :param verbose: if True, print R after every update
    :return: EC point corresponding to s * P
    """

    def short_hex(x):
        # 381 bits -> up to 96 hex chars
        h = f"{x:096x}"
        return h[:8] + "..." + h[-8:]

    R = (0, 1, 0)  # Identity element in projective coordinates
    bin_s = bin(s)[2:]           # MSB .. LSB
    n_bits = len(bin_s)

    for idx, bit in enumerate(bin_s):
        # Map loop index to bit index used in the HW spec (log2(s)-1 .. 0)
        bit_idx = n_bits - 1 - idx

        # ----- Double -----
        R = EC_addition(R, R)
        if verbose:
            print(
                f"[i={bit_idx:3d}] dbl  "
                f"Rx={short_hex(R[0])}  "
                f"Ry={short_hex(R[1])}  "
                f"Rz={short_hex(R[2])}"
            )

        # ----- Conditional add -----
        if bit == '1':
            R = EC_addition(R, P)
            if verbose:
                print(
                    f"[i={bit_idx:3d}] add  "
                    f"Rx={short_hex(R[0])}  "
                    f"Ry={short_hex(R[1])}  "
                    f"Rz={short_hex(R[2])}"
                )

    return R



def ecdsa_sign(p, m):
    while True:
        k = helpers.getRandomInt(255) % curves.groupOrder
        if k == 0:
            continue
        k_inv = helpers.Modinv(k, curves.groupOrder)
        if k_inv != -1:
            break
    G = helpers.affineToProjective(curves.G)
    K = EC_scalar_mult(k, G)
    K_affine = helpers.projectiveToAffine(K)
    r = K_affine[0] % curves.groupOrder
    s = (k_inv * ((m + ((p * r)%curves.groupOrder))%curves.groupOrder)) % curves.groupOrder
    return (K, s)


def ecdsa_verify(m, signature, P):    #m message, P public key 
    K, s = signature
    K_affine = helpers.projectiveToAffine(K)
    r = K_affine[0] % curves.groupOrder

    G = helpers.affineToProjective(curves.G)
    print(f"m            <= 255'h{m:064x};")
    print(f"G.x          <= 381'h{G[0]:096x};")
    print(f"G.y          <= 381'h{G[1]:096x};")
    print(f"G.z          <= 381'h{G[2]:096x};")

    Q = EC_scalar_mult(m, G)
    print(f"Q.x          <= 381'h{Q[0]:096x};")
    print(f"Q.y          <= 381'h{Q[1]:096x};")
    print(f"Q.z          <= 381'h{Q[2]:096x};")
    
    print("\nSW Format (as written to C file):")
    print(f"m (SW)       = {{{helpers.WriteConstants(m<<643,32)}}}")
    print(f"G.x (SW)     = {{{helpers.WriteConstants(G[0]<<643,32)}}}")
    print(f"G.y (SW)     = {{{helpers.WriteConstants(G[1]<<643,32)}}}")
    print(f"G.z (SW)     = {{{helpers.WriteConstants(G[2]<<643,32)}}}")
    print(f"Q.x (SW)     = {{{helpers.WriteConstants(Q[0]<<643,32)}}}")
    print(f"Q.y (SW)     = {{{helpers.WriteConstants(Q[1]<<643,32)}}}")
    print(f"Q.z (SW)     = {{{helpers.WriteConstants(Q[2]<<643,32)}}}\n")
    L = EC_scalar_mult(r, P)
    C = EC_addition(Q, L)
    C_prime = EC_scalar_mult(s, K)
    valid  = (C[0]*C_prime[2])%curves.q  == (C[2]*C_prime[0])%curves.q
    return  valid, C, C_prime, r

