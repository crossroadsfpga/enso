from ortools.linear_solver import pywraplp
import copy


def generateAllBitStrings(k):
    if (k == 1):
        return ['0', '1']
    smallRes = generateAllBitStrings(k-1)
    result = []
    for res in smallRes:
        result.extend(['0'+res, '1'+res])
    return result


def getAvgPayoff(a, b, play_one, play_two):
    payoff = 0
    numIters = 0
    for i in range(len(play_one)):
        for j in range(len(play_two)):
            if (i != j):
                one = play_one[i]
                two = play_two[j]
                if (one == '0'):
                    payoff -= a
                elif (one == '1' and two == '0'):
                    payoff += a
                elif (one == '1' and two == '1'):
                    if (i > j):
                        payoff += a+b
                    else:
                        payoff -= (a+b)
                numIters += 1
    return payoff / numIters


def main():
    firstLine = input()
    values = firstLine.split()
    k = int(values[0])
    a = float(values[1])
    b = float(values[2])

    player1BitStrings = generateAllBitStrings(k)
    player2BitStrings = copy.copy(player1BitStrings)

    payoffs = [[0 for _ in range(len(player2BitStrings))]
               for _ in range(len(player1BitStrings))]
    for i in range(len(player1BitStrings)):
        for j in range(len(player2BitStrings)):
            payoffs[i][j] = getAvgPayoff(
                a, b, player1BitStrings[i], player2BitStrings[j])

    solver = pywraplp.Solver.CreateSolver('GLOP')
    if not solver:
        return

    probs = []
    sumOfProbs = 0
    for row in range(len(payoffs)):
        # probabilities for each row
        p = solver.NumVar(0, 1, f'p{row}')
        probs.append(p)
        sumOfProbs += p

    v_plus = solver.NumVar(0, solver.infinity(), 'v_plus')
    v_minus = solver.NumVar(0, solver.infinity(), 'v_minus')

    for col in range(len(payoffs[0])):
        # iterating over the cols to get each constraint
        constraint = 0
        for row in range(len(payoffs)):
            constraint += (payoffs[row][col] * probs[row])
        solver.Add(v_plus - v_minus <= constraint)

    solver.Add(sumOfProbs <= 1)
    solver.Add(sumOfProbs >= 1)

    solver.Maximize(v_plus - v_minus)

    solver.Solve()
    print(solver.Objective().Value())


if __name__ == "__main__":
    main()
