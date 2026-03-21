import sys
import math
import binascii
import random

sys.setrecursionlimit(1500)

operation = 0
seed = "random"

def setSeed(seedInput):
    random.seed(seedInput)

def getModuli(bits):
    N = 1
    while bitlen(N) != bits*2:
        p     = getRandomPrime(bits)
        q     = getRandomPrime(bits)
        N     = p*q
    return [p,q,N]

def getModulus(bits):
    n = random.randrange(2**(bits-1), 2**bits-1)
    # print gcd(n, 2**bits)
    while not gcd(n, 2**bits) == 1:
        n = random.randrange(2**(bits-1), 2**bits-1)
    mod = n
    return n

def getRandomMessage(bits,M):
    return random.randrange(2**(bits-1), M); 

def getRandomMessageForCRT(p,q):
    if p < q:
        M = p
    else:
        M = q
    return random.randrange(M); 

def getRandomPrime(bits):
    n = random.randrange(2**(bits-1), 2**bits-1)
    while not isPrime(n):
        n = random.randrange(2**(bits-1), 2**bits-1)
    return n

def getRandomInt(bits):
    return random.randrange(2**(bits-1), 2**bits-1)

def getRandomExponents(p, q):
    phi = (p-1)*(q-1)
    e = getRandomPrime(16)
    while not gcd(e, phi) == 1:
        e = getRandomPrime(16)
    d = Modinv(e,phi)
    return [e,d]

def isPrime(n, k=5): # miller-rabin
    from random import randint
    if n < 2: return False
    for p in [2,3,5,7,11,13,17,19,23,29]:
        if n % p == 0: return n == p
    s, d = 0, n-1
    while d % 2 == 0:
        s, d = s+1, d >> 1
    for i in range(k):
        x = pow(randint(2, n-1), d, n)
        if x == 1 or x == n-1: continue
        for r in range(1, s):
            x = (x * x) % n
            if x == 1: return False
            if x == n-1: break
        else: return False
    return True

def bitlen(n):
    return int(math.log(n, 2)) + 1

def bit(y,index):
  bits   = [(y >> i) & 1 for i in range(1024)]
  bitstr = ''.join([chr(sum([bits[i * 8 + j] << j for j in range(8)])) for i in range(128)])
  return (ord(bitstr[index >> 3]) >> (index%8)) & 1

def gcd(x, y):
    while y != 0:
        (x, y) = (y, x % y)
    return x

def Modexp(b,e,m):
  if e == 0: return 1
  t = Modexp(b,e >> 1,m)**2 % m
  if e & 1: t = (t*b) % m
  return t

def egcd(a, b):
    if a == 0:
        return (b, 0, 1)
    else:
        g, y, x = egcd(b % a, a)
        return (g, x - (b // a) * y, y)

def Modinv(a, m):
    g, x, y = egcd(a, m)
    if g != 1:
        return -1
    else:
        return x % m

def WriteConstants(number):

    wordLenInBits = 32

    charlen = wordLenInBits >> 2

    text   = hex(number)

    # Remove unwanted characters 0x....L
    if text[-1] == "L":
        text = text[2:-1]
    else:
        text = text[2:]
        
    while (len(text)%4):
        text = "0"+text
    
    
    # Split the number into word-bit chunks
    text   = text.zfill(len(text) + len(text) % charlen)  
    # result = ' '.join("0x"+text[i: i+charlen]+"," for i in range(0, len(text), charlen)) 
    result = ' '.join("0x"+text[i: i+charlen]+"," for i in reversed(range(0, len(text), charlen))) 

    # Remove the last comma
    result = result[:-1]

    return result


print ("====================================================================")
print ("TEST VECTOR GENERATOR FOR DDP SW SESSIONS")

if len(sys.argv) == 3:
  print ("--> Seed is ", sys.argv[2])
  seed = sys.argv[2]
  setSeed(sys.argv[2])
else:
  print ("--> No seed specified")

if len(sys.argv) == 2 or len(sys.argv) == 3:
  if str(sys.argv[1]) == "add":         operation = 1;
  if str(sys.argv[1]) == "sub":         operation = 2;
  if str(sys.argv[1]) == "mod_add":     operation = 3;
  if str(sys.argv[1]) == "mod_sub":     operation = 4;
  if str(sys.argv[1]) == "mul":         operation = 5;
  if str(sys.argv[1]) == "mont_mul":    operation = 6;

print ("====================================================================")

#####################################################

if operation == 0:
  print ("You should use this script by passing an argument like:")
  print (" $ python software_tv.py add")
  print (" $ python software_tv.py mod_add")
  print (" $ python software_tv.py sub")
  print (" $ python software_tv.py mod_sub")
  print (" $ python software_tv.py mul")
  print (" $ python software_tv.py mont_mul")
  print ("")
  print ("You can also set a seed for randomness to work")
  print ("with the same software_tv at each execution:")
  print (" $ python software_tv.py add 2025")
  print ("")

#####################################################

if operation == 1:
  print ("Test Vector for Multi Precision Addition\n")

  a = getRandomInt(1024)
  b = getRandomInt(1024)
  c = a + b

  print ("a                = ", hex(a).rstrip("L"))          # 1024-bits
  print ("b                = ", hex(b).rstrip("L"))          # 1024-bits
  print ("a + b            = ", hex(c).rstrip("L"))          # 1024-bits
  
  print ("====================================================================")
  print ("Input variable declaration in C language\n")
  
  print ("uint32_t a[32]   = {", WriteConstants(a), "};")    # 1024-bits
  print ("uint32_t b[32]   = {", WriteConstants(b), "};")    # 1024-bits
  
  print ("====================================================================")

#####################################################

if operation == 2:
  print ("Test Vector for Multi Precision Subtraction\n")

  a = getRandomInt(1024)
  b = getRandomMessage(1024,a)
  c = a - b

  print ("a                = ", hex(a).rstrip("L"))           # 1024-bits
  print ("b                = ", hex(b).rstrip("L"))           # 1024-bits
  print ("a - b            = ", hex(c).rstrip("L"))           # 1024-bits
  
  print ("====================================================================")
  print ("Input variable declaration in C language\n")
  
  print ("uint32_t a[32]   = {", WriteConstants(a), "};")    # 1024-bits
  print ("uint32_t b[32]   = {", WriteConstants(b), "};")    # 1024-bits
  
  print ("====================================================================")

#####################################################

if operation == 3:
  print ("Test Vector for Multi Precision Modular Addition\n")
  
  [p,q,n] = getModuli(512)

  a = getRandomMessage(1024,n)
  b = getRandomMessage(1024,n)
  c = (a + b) % n

  print ("a                = ", hex(a).rstrip("L"))           # 1024-bits
  print ("b                = ", hex(b).rstrip("L"))           # 1024-bits
  print ("n                = ", hex(n).rstrip("L"))           # 1024-bits
  print ("(a + b) mod n    = ", hex(c).rstrip("L"))           # 1024-bits
  
  print ("====================================================================")
  print ("Input variable declaration in C language\n")
  
  print ("uint32_t a[32]   = {", WriteConstants(a), "};")    # 1024-bits
  print ("uint32_t b[32]   = {", WriteConstants(b), "};")    # 1024-bits
  print ("uint32_t n[32]   = {", WriteConstants(n), "};")    # 1024-bits
  
  print ("====================================================================")
  
#####################################################

if operation == 4:

  print ("Test Vector for Multi Precision Modular Subtraction\n")
  
  [p,q,n] = getModuli(512)

  a = getRandomMessage(1024,n)
  b = getRandomMessage(1024,n)
  c = (a - b) % n

  print ("a                = ", hex(a).rstrip("L"))           # 1024-bits
  print ("b                = ", hex(b).rstrip("L"))           # 1024-bits
  print ("n                = ", hex(n).rstrip("L"))           # 1024-bits
  print ("(a - b) mod n    = ", hex(c).rstrip("L"))           # 1024-bits
  
  print ("====================================================================")
  print ("Input variable declaration in C language\n")
  
  print ("uint32_t a[32]   = {", WriteConstants(a), "};")    # 1024-bits
  print ("uint32_t b[32]   = {", WriteConstants(b), "};")    # 1024-bits
  print ("uint32_t n[32]   = {", WriteConstants(n), "};")    # 1024-bits
  
  print ("====================================================================")

#####################################################

if operation == 5:

  print ("Test Vector for Multi Precision Multiplication\n")

  a = getRandomInt(1024)
  b = getRandomInt(1024)
  c = a * b

  print ("a                = ", hex(a).rstrip("L"))           # 1024-bits
  print ("b                = ", hex(b).rstrip("L"))           # 1024-bits
  print ("a * b            = ", hex(c).rstrip("L"))           # 1024-bits
  
  print ("====================================================================")
  print ("Input variable declaration in C language\n")
  
  print ("uint32_t a[32]   = {", WriteConstants(a), "};")    # 1024-bits
  print ("uint32_t b[32]   = {", WriteConstants(b), "};")    # 1024-bits
  
  print ("====================================================================")

#####################################################

if operation == 6:

  print ("Test Vector for Multi Precision Montgomery Multiplication\n")

  [p,q,n] = getModuli(512)
  
  r = 2**1024  
  r_inv = Modinv(r, n)
  
  n_prime = (r - Modinv(n, r))

  a = getRandomMessage(1024,n)
  b = getRandomMessage(1024,n)
  c = (a * b * r_inv) % n

  print ("a                      = ", hex(a).rstrip("L"))           # 1024-bits
  print ("b                      = ", hex(b).rstrip("L"))           # 1024-bits
  print ("n                      = ", hex(n).rstrip("L"))           # 1024-bits
  print ("n_prime                = ", hex(n_prime).rstrip("L"))     # 1024-bits
  print ("a * b                  = ", hex(a*b).rstrip("L"))         # 1024-bits
  print ("(a * b * r-1) mod n    = ", hex(c).rstrip("L"))           # 1024-bits
  
  print ("====================================================================")
  print ("Input variable declaration in C language\n")
  
  print ("uint32_t a[32]         = {", WriteConstants(a), "};")    # 1024-bits
  print ("uint32_t b[32]         = {", WriteConstants(b), "};")    # 1024-bits
  print ("uint32_t n[32]         = {", WriteConstants(n), "};")    # 1024-bits
  print ("uint32_t n_prime[32]   = {", WriteConstants(n_prime), "};")    # 1024-bits
  print ("uint32_t res[32]       = {", WriteConstants(c), "};")    # 1024-bits
  
  print ("====================================================================")
