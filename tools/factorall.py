#!/usr/bin/env python3
from __future__ import with_statement, division, print_function
from itertools import chain
from operator import mul
from heapq import nlargest

def primewheel(i):
    wheel = [7, 11, 13, 17, 19, 23, 29, 31]
    wheeladd = 0
    remain = chain([2, 3, 5], wheel)
    while True:
        for pp in remain:
            yield pp + wheeladd
        wheeladd += 30

def primefac(i):
    factors = []
    for pp in primewheel(i):
        while i % pp == 0:
            factors.append(pp)
            i = i // pp
        if pp * pp > i:
            if i > 1:
                factors.append(i)
            return factors

# untested
def primefacs_sqrt(i):
    numtwos = 0
    while i % 4 == 0:
        i = i // 4
        num_twos += 1
    if i % 4 == 2:
        return None
    last_pf = 0
    sqrtval = 1
    while i > 1:
        pf, i = primefacslist[i // 2]
        if last_pf:
            if last_pf != pf:
                return None
            last_pf = 0
            sqrtval *= pf
        else:
            last_pf = pf
    return sqrtval if last_pf == 0 else None      

def factorGenerator(i):
    """Read out prime factors and their powers from the prime factor list."""
    last_pf, pfpow = 2, 0
    while i % 2 == 0:
        i = i // 2
        pfpow += 1
    while i > 1:
        pf, i = primefacslist[i // 2]
        if pf != last_pf:
            yield (last_pf, pfpow)
            last_pf, pfpow = pf, 0
        pfpow += 1
    if pfpow:
        yield (last_pf, pfpow)
    
# The set of a number's divisors is the set of products of all
# submultisets of its PFs.
def all_divisors(i):
    pffreqs = list(factorGenerator(i))
    if not pffreqs:
        yield 1
        return
    pows = [0] * len(pffreqs)
    divaccum = [1] * len(pffreqs)
    while True:
        yield divaccum[0]
        for i in range(len(pows)):
            pows[i] += 1
            if pows[i] <= pffreqs[i][1]:
                divaccum[i] *= pffreqs[i][0]
                divaccum[:i + 1] = [divaccum[i]] * (i + 1)
                break
            pows[i] = 0
            if i + 1 == len(pows):
                return


# f[i] is the prime factorization of 2*i+1
primefacs = [primefac(2 * i + 1) for i in range(50)]
# most PFs is 96 = 2*2*2*2*2*3
# most distinct PFs is 30 = 2*3*5
# most divisors (product of 1 + each PF's power) is 60 = 2^2*3*5

# Convert these to a linked list as described below.
primefacslist = [(pfs[0], (2 * i + 1) // pfs[0])
                 if pfs
                 else (1, 1)
                 for (i, pfs) in enumerate(primefacs)]

##print("\n".join("%d = %d * %d" % (2 * i + 1, spf, pfquotient)
##      for i, (spf, pfquotient) in enumerate(primefacslist)))

##print("\n".join("%d: %s" % (i, repr(list(all_divisors(i))))
##                for i in range(1, 101)))

# With this you can check if something is prime by looking for
# a > 1 and b = 1, and you can check if it is square by seeing if
# all PFs come in pairs.
print("""; prime factorization linked list generated with factorall.py
; This is the smallest prime factor (PF) of each odd number followed
; by the quotient after dividing by that factor.  These act as the
; car and cdr in a singly linked list because a number's PFs are its
; smallest PF followed by the PFs of the number divided by its
; smallest PF.
; PFs(x) = PFs(x)[0] . PFs(x / PF(x)[0])
.export prime_factorization
.segment "RODATA"
prime_factorization:""")
print("\n".join("  .byte %d,%d" % row for row in primefacslist))
