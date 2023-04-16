def medianFunc(l):
    return l[len(l)//2]

def findRoughMedian(l):
    if len(l)==1:
        return l[0]
    medians = []
    for i in range(0, len(l), 5):
        group = l[i:min(len(l), i+5)]
        group.sort()
        median = medianFunc(group)
        medians.append(median)
    return findRoughMedian(medians)

def deterministicSelect(l, k):
    p = findRoughMedian(l)
    less = []
    greater = []
    equal = []
    for num in l:
        if num < p:
            less.append(num)
        elif num > p:
            greater.append(num)
        else:
            equal.append(num)
    if len(less) == k-1 or (len(less) < k and k <= len(less) + len(equal)):
        return p
    elif len(less) < k:
        return deterministicSelect(equal[1:] + greater, k-len(less)-1)
    else:
        return deterministicSelect(less, k)

def main():
    firstLine = input()
    secondLine = input()
    sizes = firstLine.split()
    k = int(sizes[1])
    numsString = secondLine.split()
    nums = []
    for num in numsString:
        nums.append(int(num))
    print(deterministicSelect(nums, k))

if __name__ == "__main__":
    main()