import helpers
from modularFunct import *
from curves import *
from math import *
import curves


# Here we don't implement the functions 
# as the students should implement them
# in their software lab sessions

def MontMul(A, B, M):
    # Returns (A*B*Modinv(R,M)) mod M
    R = 2**381
    return (A*B*helpers.Modinv(R,M)) % M
    
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
    # DO YOU REALLY NEED TO DO A MULTIPLICATION?
    # EASY TO IMPLEMENT BUT YOU LOSE ON PERFORMANCE
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

def EC_scalar_mult(s, P):
    """
    :param s: Integer scalar (e.g., 255-bit)
    :param P: EC point (e.g., in affine or projective coordinates)
    :return: EC point corresponding to s * P
    """
    R = (0, 1, 0)  # Identity element in projective coordinates (adjust if using affine)
    bin_s = bin(s)[2:]  # Convert scalar to binary string without '0b' prefix
    for bit in bin_s:
        R = EC_addition(R, R)  # Point doubling
        if bit == '1':
            R = EC_addition(R, P)  # Point addition
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
    Q = EC_scalar_mult(m, G)
    L = EC_scalar_mult(r, P)
    C = EC_addition(Q, L)
    # print(f"C.x          <= 381'h{(C[0])<<(3):96x};") # we shift up by 3 bits and therefore pad with 3 zeros
    # print(f"C.y          <= 381'h{(C[1])<<(3):96x};") # this way, the hex looks the same when compared with how we will find the result in the test run
    # print(f"C.z          <= 381'h{(C[2])<<(3):96x};")
    C_prime = EC_scalar_mult(s, K)
    valid  = (C[0]*C_prime[2])%curves.q  == (C[2]*C_prime[0])%curves.q
    return  valid, C, C_prime, r, Q, L
