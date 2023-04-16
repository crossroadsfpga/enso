class Graph:
    def __init__(self, grid, n, m):
        # let s be at (-1, -1) and t be at (m, n)
        self.grid = grid
        self.rows = n
        self.cols = m
        self.nodes = {(-1, -1): Node(-1, -1, {}, {}), (n, m): Node(n, m, {}, {})}
        for row in range(n):
            for col in range(m):
                self.nodes[(row, col)] = Node(row, col, {}, {})

    def getNode(self, row, col):
        return self.nodes[(row, col)]

    def addEdge(self, row, col, nrow, ncol, capacity):
        self.getNode(row, col).addEdgeTo(nrow, ncol, capacity)
        self.getNode(nrow, ncol).addEdgeFrom(row, col, capacity)

    def getSource(self):
        return self.nodes[(-1, -1)]
    
    def getSink(self):
        return self.nodes[(self.rows, self.cols)]
    
    def isValid(self, row, col):
        return row>=0 and col>=0 and row<self.rows and col<self.cols

    def getNeighbors(self, row, col):
        result = []
        for (nrow, ncol) in [(row+1, col), (row-1, col), (row, col+1), (row, col-1)]:
            if self.isValid(nrow, ncol) and self.grid[nrow][ncol] != "x":
                result.append((nrow, ncol))
        return result
    
class Node:
    def __init__(self, row, col, edgesTo, edgesFrom):
        self.row = row
        self.col = col
        self.edgesTo = edgesTo
        self.edgesFrom = edgesFrom
    
    def addEdgeTo(self, nrow, ncol, capacity):
        self.edgesTo[(nrow, ncol)] = Edge((self.row, self.col), (nrow, ncol), capacity, True)
    
    def addEdgeFrom(self, nrow, ncol, capacity):
        self.edgesFrom[(nrow, ncol)] = Edge((nrow, ncol), (self.row, self.col), capacity, False)

    def printNode(self):
        edgesArray = []
        if len(self.edgesTo) > 1:
            edges = self.edgesTo
            for _, edge in edges.items():
                edgesArray.append((edge.end, edge.capacity, edge.flow))
        else:
            edges = self.edgesFrom
            for _, edge in edges.items():
                edgesArray.append((edge.start, edge.capacity, edge.flow))
        # print(self.row, self.col, edgesArray)
    
    def getEdgesToWithPositiveFlow(self):
        result = []
        for _, edge in self.edgesTo.items():
            if edge.flow == 1:
                result.append(edge)
        return result
    
    def getEdgesFromWithPositiveFlow(self):
        result = []
        for _, edge in self.edgesFrom.items():
            if edge.flow == 1:
                result.append(edge)
        return result

class Edge:
    def __init__(self, start, end, capacity, forward):
        self.start = start # (row, col) pair
        self.end = end
        self.capacity = capacity
        self.flow = 0
        self.forward = forward
    
    def getResidualCapacity(self):
        if self.forward:
            return self.capacity - self.flow
        else:
            return self.flow

def addToGraph(graph, grid, row, col, visited, currSide):
    if (row, col) in visited:
        return
    if grid[row][col] == "x":
        return
    visited.add((row, col))
    if currSide == 0:
        # adding edge from source to node
        graph.addEdge(-1, -1, row, col, 2) # capacity 2 so node can have 2 neighbors with flow
        # adding edge between node and its valid neighbors
        neighbors = graph.getNeighbors(row, col)
        for (nrow, ncol) in neighbors:
            graph.addEdge(row, col, nrow, ncol, 1)
            addToGraph(graph, grid, nrow, ncol, visited, 1)
    else:
        # in this case, node has already been added to graph
        sink = graph.getSink()
        graph.addEdge(row, col, sink.row, sink.col, 2)
        # must call for neighbors
        neighbors = graph.getNeighbors(row, col)
        for (nrow, ncol) in neighbors:
            addToGraph(graph, grid, nrow, ncol, visited, 0)

def getPathPosResCap(graph):
    def dfs(row, col, visited, currPath, currResCap):
        if row == graph.rows and col == graph.cols:
            # reached sink node! 
            return (currPath + [(row, col)], currResCap)

        if (row, col) in visited:
            return None
        visited.add((row, col))

        node = graph.getNode(row, col)

        for _, edge in node.edgesTo.items():

            # checking if edge has positive residual capacity
            resCap = edge.getResidualCapacity()
            if resCap > 0:
                (nrow, ncol) = edge.end
                res = dfs(nrow, ncol, visited, currPath + [(row, col)], min(currResCap, resCap))
                if res != None:
                    return res
        
        for _, edge in node.edgesFrom.items():
            resCap = edge.getResidualCapacity()
            (nrow, ncol) = edge.start
            if resCap > 0:
                res = dfs(nrow, ncol, visited, currPath + [(row, col)], min(currResCap, resCap))
                if res != None:
                    return res
        
        return None
        
    return dfs(-1, -1, set(), [], float("inf"))

def pushFlow(graph, path, flow):
    for i in range(len(path)-1):
        (row, col) = path[i]
        (nrow, ncol) = path[i+1]
        node = graph.getNode(row, col)
        nextNode = graph.getNode(nrow, ncol)

        if (nrow, ncol) in node.edgesTo:
            # know that this is forward, can just add to flow
            node.edgesTo[(nrow, ncol)].flow += flow
            nextNode.edgesFrom[(row, col)].flow += flow
        else:
            node.edgesFrom[(nrow, ncol)].flow -= flow
            nextNode.edgesTo[(row, col)].flow -= flow

def fordFulkerson(graph):
    # while there exists a path of positive residual capacity
    res = getPathPosResCap(graph)
    while res:
        (path, flow) = res
        pushFlow(graph, path, flow)
        res = getPathPosResCap(graph)
    
def drawGrid(graph, grid):
    def dfs(row, col, visited, currSide):
        if (row, col) in visited:
            return
        visited.add((row, col))
        node = graph.getNode(row, col)
        if currSide == 0:
            [edge1, edge2] = node.getEdgesToWithPositiveFlow()
            (nrow1, ncol1), (nrow2, ncol2) = edge1.end, edge2.end
            if nrow1 > row or nrow2 > row:
                if nrow1 < row or nrow2 < row:
                    grid[row][col] = "|"
                elif ncol1 < col or ncol2 < col:
                    grid[row][col] = "7"
                elif ncol1 > col or ncol2 > col:
                    grid[row][col] = "r"
            elif nrow1 < row or nrow2 < row:
                if ncol1 < col or ncol2 < col:
                    grid[row][col] = "J"
                elif ncol1 > col or ncol2 > col:
                    grid[row][col] = "L"
            else:
                grid[row][col] = "-"
            dfs(nrow1, ncol1, visited, 1)
            dfs(nrow2, ncol2, visited, 1)
        else:
            [edge1, edge2] = node.getEdgesFromWithPositiveFlow()
            (nrow1, ncol1), (nrow2, ncol2) = edge1.start, edge2.start
            if nrow1 > row or nrow2 > row:
                if nrow1 < row or nrow2 < row:
                    grid[row][col] = "|"
                elif ncol1 < col or ncol2 < col:
                    grid[row][col] = "7"
                elif ncol1 > col or ncol2 > col:
                    grid[row][col] = "r"
            elif nrow1 < row or nrow2 < row:
                if ncol1 < col or ncol2 < col:
                    grid[row][col] = "J"
                elif ncol1 > col or ncol2 > col:
                    grid[row][col] = "L"
            else:
                grid[row][col] = "-"
            
            dfs(nrow1, ncol1, visited, 0)
            dfs(nrow2, ncol2, visited, 0)
            
    source = graph.getSource()
    visited = set()
    for (nrow, ncol) in source.edgesTo:
        dfs(nrow, ncol, visited, 0)

def main():
    firstLine = input()
    sizes = firstLine.split()
    n = int(sizes[0])
    m = int(sizes[1])
    grid = [['' for _ in range(m)] for _ in range(n)]
    # load grid into a 2D list
    for row in range(n):
        rowContent = input()
        for col in range(m):
            grid[row][col] = rowContent[col]

    # convert grid to bipartite graph
    graph = Graph(grid, n, m)
    visited = set()
    for row in range(n):
        for col in range(m):
            addToGraph(graph, grid, row, col, visited, 0)

    # must run ford-fulkerson on graph
    fordFulkerson(graph)

    source = graph.getSource()
    for _, edge in source.edgesTo.items():
        if edge.flow < 2:
            print("NO")
            return
    
    print("YES")

    # must draw graph out now
    newGrid = [["" for _ in range(m)] for _ in range(n)]
    drawGrid(graph, newGrid)
    for row in range(n):
        for col in range(m):
            if newGrid[row][col] == "":
                newGrid[row][col] = "x"
    for row in newGrid:
        print("".join(row))

if __name__ == "__main__":
    main()