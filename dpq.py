import math
import random

def getNumRep(c):
    return ord(c)-48

def hash(x, p):
    return x % p

def isPrime(n):
    sqrt = math.ceil(math.sqrt(n))
    for i in range(2, sqrt+1):
        if n%i == 0:
            return False
    return True

def selectPrime(n):
    s = 100
    val = random.randint(2, math.ceil((2*s*n)*(math.log(s*n, 2))))
    while not isPrime(val):
        val = random.randint(2, math.ceil((2*s*n)*(math.log(s*n, 2))))
    return val

def nextPowerOfTwo(val):
    res = 1
    while (res < val):
        res = res * 2
    return res

class Segtree:
    def powers(self, b, n, p):
        result = [1]
        for i in range(n):
            result.append((result[-1]*b) % p)
        return result

    def __init__(self, a, p, b):
        self.n = len(a) 
        self.p = p # prime to take modulo of
        self.totalNumNodes = nextPowerOfTwo(self.n) # number of leaves in tree
        self.powers = self.powers(b, self.totalNumNodes, p)
        self.A = [(0, 0) for _ in range(2*self.totalNumNodes-1)]
        for i in range(0, self.n):
            self.A[self.totalNumNodes+i-1] = (getNumRep(a[i]), 1)
        self.build(0, 0, self.totalNumNodes)
    
    def parent(self, i):
        return math.floor((i-1)/2)
    
    def leftChild(self, i):
        return 2*i+1
    
    def rightChild(self, i):
        return 2*i+2

    def combine(self, hashLeft, numBitsLeft, hashRight, numBitsRight):
        return (((hashLeft * self.powers[numBitsRight]) + hashRight) % self.p, numBitsLeft + numBitsRight)

    def build(self, u, L, R):
        mid = (L+R)//2
        if self.leftChild(u) < self.totalNumNodes-1:
            self.build(self.leftChild(u), L, mid)
        if self.rightChild(u) < self.totalNumNodes-1:
            self.build(self.rightChild(u), mid, R)
        (hashLeft, numBitsLeft) = self.A[self.leftChild(u)]
        (hashRight, numBitsRight) = self.A[self.rightChild(u)]
        self.A[u] = self.combine(hashLeft, numBitsLeft, hashRight, numBitsRight)
    
    # x here is a character
    def assign(self, i, x):
        u = i + self.totalNumNodes - 1
        self.A[u] = (getNumRep(x), 1)
        while u > 0:
            u = self.parent(u)
            (hashRight, numBitsRight) = self.A[self.rightChild(u)]
            (hashLeft, numBitsLeft) = self.A[self.leftChild(u)]
            self.A[u] = self.combine(hashLeft, numBitsLeft, hashRight, numBitsRight)
    
    def computeHash(self, u, i, j, L, R):
        if i <= L and R <= j:
            return self.A[u]
        (_, mid) = self.A[self.leftChild(u)]
        mid = mid + L
        if i >= mid:
            return self.computeHash(self.rightChild(u), i, j, mid, R)
        elif j <= mid:
            return self.computeHash(self.leftChild(u), i, j, L, mid)
        else:
            (hashLeft, numBitsLeft) = self.computeHash(self.leftChild(u), i, j, L, mid)
            (hashRight, numBitsRight) = self.computeHash(self.rightChild(u), i, j, mid, R)
            return self.combine(hashLeft, numBitsLeft, hashRight, numBitsRight)
    
    def rangeHash(self, i, j):
        res = self.computeHash(0, i, j, 0, self.n)
        return res


def generateHashTree(T, p, b):
    return Segtree(T, p, b)

def M(hashes, reverseHashes, i, c):
    hashes.assign(i, c)
    reverseHashes.assign(hashes.n - i - 1, c)

def Q(hashes, reverseHashes, i, j):
    hash = hashes.rangeHash(i, j+1)
    revHash = reverseHashes.rangeHash(hashes.n-j-1, hashes.n-i)
    if hash == revHash:
        return "YES"
    else:
        return "NO"

def P(hashes, reverseHashes, i, k, j):
    (firstHash, firstHashBits), (secondHash, secondHashBits) = (0, 0), (0, 0)
    (firstHashRev, firstHashBitsRev), (secondHashRev, secondHashBitsRev) = (0, 0), (0, 0)    
    if k > i:
        (firstHash, firstHashBits)= hashes.rangeHash(i, k)
        (firstHashRev, firstHashBitsRev)= reverseHashes.rangeHash(hashes.n - k, hashes.n-i)
    if k < j:
        (secondHash, secondHashBits) = hashes.rangeHash(k+1, j+1)
        (secondHashRev, secondHashBitsRev) = reverseHashes.rangeHash(hashes.n-j-1, hashes.n-k-1)
    
    overallHash = hashes.combine(firstHash, firstHashBits, secondHash, secondHashBits)
    overallHashRev = hashes.combine(secondHashRev, secondHashBitsRev, firstHashRev, firstHashBitsRev)

    if overallHash == overallHashRev:
        return "YES"
    else:
        return "NO"

def main():
    firstLine = input()
    sizes = firstLine.split()
    n = int(sizes[0])
    m = int(sizes[1])
    T = input()
    b = 75
    p = selectPrime(len(T))
    hashesSegtree = generateHashTree(T, p, b)
    reverseHashesSegTree = generateHashTree(T[::-1], p, b)
    for i in range(m):
        query = input()
        parts = query.split()
        if parts[0] == "M":
            M(hashesSegtree, reverseHashesSegTree, int(parts[1]), parts[2])
        elif parts[0] == "Q":
            print(Q(hashesSegtree, reverseHashesSegTree, int(parts[1]), int(parts[2])))
        else:
            print(P(hashesSegtree, reverseHashesSegTree, int(parts[1]), int(parts[2]), int(parts[3])))

if __name__ == "__main__":
    main()