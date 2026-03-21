from curves import *
from math import *
import random


def gcdExtended(a, b):
    # https://www.geeksforgeeks.org/python-program-for-basic-and-extended-euclidean-algorithms-2/
    # Python program to demonstrate working of extended Euclidean Algorithm
    # function for extended Euclidean Algorithm
    # Base Case
    if a == 0 :
        return 0,1         
    x1,y1 = gcdExtended(modularReduction(b,a), a)
    # Update x and y using results of recursive call
    x = y1 - (b//a) * x1
    y = x1
    return x,y

def modularInverse(x,m=q):
    x = modularReduction(x,m)
    a,b = gcdExtended(x,m)
    if a<0:
        a = m + a
    return a

def modularReduction(x,m=q):
    return x % m
