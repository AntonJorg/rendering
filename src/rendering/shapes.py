import numpy as np
from transformations import rotation, translation


class ProjectiveElement:
    """
    Base class.
    """

    def __init__(self, pos=(0, 0, 0), rot=(0, 0, 0)):
        self.transform = translation(*pos) @ rotation(*rot)

    def __matmul__(self, other):
        # TODO: Make this make sense algebra wise
        self.transform = other @ self.transform


class Shape(ProjectiveElement):

    def __init__(self, pos=(0, 0, 0), rot=(0, 0, 0), vertices=np.zeros((0, 4)), edges=np.zeros((0, 2))):
        self._vertices = vertices
        self._edges = edges
        self._triangles = self.triangles_from_edges()
        super().__init__(pos=pos, rot=rot)

    @property
    def vertices(self):
        return (self.transform @ self._vertices.T).T

    @property
    def triangles(self):
        return self._triangles

    def triangles_from_edges(self):
        triangles = np.zeros((0, 3))
        for i in range(0, len(self._edges) - 1):
            for j in range(i + 1, len(self._edges)):
                e1 = self._edges[i]
                e2 = self._edges[j]
                if e1[0] == e2[0]:
                    if np.any(np.all(np.array([e1[1], e2[1]]) == self._edges, axis=1)):
                        triangles = np.vstack((triangles, np.array([e1[0], e1[1], e2[1]])))
                else:
                    break
        return np.unique(triangles, axis=0).astype(int)


class Cube(Shape):

    def __init__(self, pos=(0, 0, 0), rot=(0, 0, 0), length=1):

        a = length / 2

        vertices = np.array([
            [a,   a,  a, 1],
            [-a,  a,  a, 1],
            [a,  -a,  a, 1],
            [-a, -a,  a, 1],
            [a,   a, -a, 1],
            [-a,  a, -a, 1],
            [a,  -a, -a, 1],
            [-a, -a, -a, 1]
        ])

        self.colors = np.random.randint(256, size=(8, 3))

        edges = np.array([
            [0, 1],
            [0, 2],
            [0, 3],
            [0, 4],
            [0, 6],
            [1, 3],
            [1, 4],
            [1, 5],
            [2, 3],
            [2, 6],
            [2, 7],
            [3, 5],
            [3, 7],
            [4, 5],
            [4, 6],
            [4, 7],
            [5, 7],
            [6, 7]
        ])

        super().__init__(pos=pos, rot=rot, vertices=vertices, edges=edges)


class Sphere(Shape):
    def __init__(self, pos=(0, 0, 0), rot=(0, 0, 0), radius=1, resolution=6):

        vertices = np.zeros((0, 4))
        edges = np.zeros((0, 2))

        # TODO: Fix ugly sphere generation

        total_vertices = (resolution - 2) * resolution + 2

        for lat in range(resolution):
            lat_angle = (np.pi * lat) / (resolution - 1)
            if lat == 0:
                point = np.array([0, 0, radius, 1])
                vertices = np.vstack((vertices, point))
                new_edges = np.zeros((resolution, 2))
                for i in range(resolution):
                    new_edges[i, 0] = 0
                    new_edges[i, 1] = i + 1
                edges = np.vstack((edges, new_edges))
            elif lat == resolution - 1:
                point = np.array([0, 0, -radius, 1])
                vertices = np.vstack((vertices, point))
                new_edges = np.zeros((resolution, 2))
                for i in range(0, resolution,):
                    new_edges[i, 0] = total_vertices - 1
                    new_edges[i, 1] = total_vertices - 2 - i
                edges = np.vstack((edges, new_edges))
            else:
                for long in range(resolution * 2):
                    long_angle = (2 * np.pi * long) / (resolution * 2 - 1)

                    point = np.array([np.cos(long_angle) * np.sin(lat_angle) * radius,
                                      np.sin(long_angle) * np.sin(lat_angle) * radius,
                                      np.cos(lat_angle) * radius, 1])

                    vertices = np.vstack((vertices, point))

                    vertex_i = 1 + (lat - 1) * resolution + long

                    if lat == resolution - 2 and long == resolution - 1:
                        new_edge = np.array([vertex_i, vertex_i - resolution])
                        edges = np.vstack((edges, new_edge))
                    elif lat == resolution - 2:
                        new_edge = np.array([vertex_i, vertex_i + 1])
                        edges = np.vstack((edges, new_edge))
                    elif long == resolution - 2:
                        new_edges = np.zeros((3, 2))

                        new_edges[0] = np.array([vertex_i, vertex_i + 1])
                        new_edges[1] = np.array([vertex_i + 1, vertex_i + 1 + resolution])
                        new_edges[2] = np.array([vertex_i + 1 + resolution, vertex_i])

                        edges = np.vstack((edges, new_edges))
                    else:
                        new_edges = np.zeros((3, 2))

                        new_edges[0] = np.array([vertex_i, vertex_i + 1])
                        new_edges[1] = np.array([vertex_i + 1, vertex_i + 1 + resolution])
                        new_edges[2] = np.array([vertex_i + 1 + resolution, vertex_i])

                        edges = np.vstack((edges, new_edges))

        super().__init__(pos=pos, rot=rot, vertices=vertices, edges=edges)
