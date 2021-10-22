import numpy as np
import matplotlib.pyplot as plt
from transformations import translation, rotation
from shapes import ProjectiveElement, Cube, Sphere


class Camera(ProjectiveElement):
    """
    https://staff.fnwi.uva.nl/r.vandenboomgaard/IPCV20162017/LectureNotes/CV/PinholeCamera/PinholeCamera.html
    """

    num_of_cams = 0

    def __init__(self,
                 pos=(0, 0, -5),
                 rot=(0, 0, 0),
                 dim=(72, 128, 3),
                 name=f"Camera {num_of_cams}",
                 f=1.,
                 alpha=0):

        Camera.num_of_cams += 1

        self.name = name
        self.dim = dim
        self.aspect_ratio = dim[1] / dim[0]
        self.f = f
        self.alpha = alpha

        super().__init__(pos=pos, rot=rot)

    @property
    def external(self):
        return np.concatenate((self.transform[:3, :3].T,
                               -self.transform[:3, :3].T @ self.transform[:3, 3].reshape((-1, 1))), axis=1)

    @property
    def internal(self):
        return np.array([
            [self.f * self.dim[0], self.alpha,           self.dim[1]/2, 0],
            [0,                    self.f * self.dim[0], self.dim[0]/2, 0],
            [0,                    0,                    1,             0]
        ])

    @property
    def camera_matrix(self):
        return self.internal[:, :3] @ self.external

    def world_coords_to_screen_coords(self, x):
        res = (self.camera_matrix @ x.T).T
        res[:, :2] = res[:, :2] / res[:, 2].reshape((-1, 1))
        return res

    def world_coords_to_camera_coords(self, x):
        return (self.external @ x.T).T

    def snap(self, objects):
        frame = np.zeros(self.dim)

        points = self.world_coords_to_screen_coords(objects)

        mask = ((points[:, 0] >= 0) & (points[:, 0] < self.dim[1])) &\
               ((points[:, 1] >= 0) & (points[:, 1] < self.dim[0]))

        points = points[mask, :].astype("uint8")

        frame[points[:, 1].astype(int), points[:, 0].astype(int)] = np.array((255, 255, 255))

        return frame.astype("uint8")

    def raster(self, shapes, background):
        z_buffer = np.ones(self.dim[:-1]) * np.inf

        frame = np.zeros(self.dim)
        frame[:, :] = background

        for shape in shapes:
            screen_coords = self.world_coords_to_screen_coords(shape.vertices)

            for triangle in shape.triangles:
                points = screen_coords[triangle]
                colors = shape.colors[triangle]

                # get bounding rectangle for triangle
                xmin, xmax = np.floor(np.min(points[:, 0])), np.ceil(np.max(points[:, 0]))
                ymin, ymax = np.floor(np.min(points[:, 1])), np.ceil(np.max(points[:, 1]))

                xmin, xmax = np.clip([xmin, xmax], 0, self.dim[1] - 1)
                ymin, ymax = np.clip([ymin, ymax], 0, self.dim[0] - 1)

                area = edge_function(*points)

                for y in range(int(ymin), int(ymax) + 1):
                    for x in range(int(xmin), int(xmax) + 1):
                        p = (x, y)

                        w1 = edge_function(points[1], points[2], p)
                        w2 = edge_function(points[2], points[0], p)
                        w3 = edge_function(points[0], points[1], p)

                        if (w1 >= 0 and w2 >= 0 and w3 >= 0) or (w1 < 0 and w2 < 0 and w3 < 0):
                            w1 = w1 / area
                            w2 = w2 / area
                            w3 = w3 / area

                            z = w1 * points[0, 2] + w2 * points[1, 2] + w3 * points[2, 2]

                            if z < z_buffer[y, x]:
                                z_buffer[y, x] = z

                                r = w1 * colors[0, 0] + w2 * colors[1, 0] + w3 * colors[2, 0]
                                g = w1 * colors[0, 1] + w2 * colors[1, 1] + w3 * colors[2, 1]
                                b = w1 * colors[0, 2] + w2 * colors[1, 2] + w3 * colors[2, 2]

                                frame[y, x] = np.array([r, g, b])

        return frame.astype("uint8")


def edge_function(point, v1, v2):
    return (v2[0] - point[0]) * (v1[1] - point[1]) - (v2[1] - point[1]) * (v1[0] - point[0])


if __name__ == "__main__":
    cam = Camera()
    #cam @ (translation(0, 5, -5) @ rotation(np.pi/4, 0, 0))
    print(cam.name)
    print(cam.camera_matrix)
    print(cam.aspect_ratio)

    cube = Cube(length=2)
    points = cube.vertices

    print(points)

    screen_coords = cam.world_coords_to_screen_coords(points)
    print(screen_coords)

    fig = plt.figure(figsize=(15, 15))
    ax = fig.add_subplot(111, projection='3d')
    ax.set_xlim([-3, 3])
    ax.set_ylim([-3, 3])
    ax.set_zlim([-3, 3])

    c = cam.transform
    cols = ["green", "red", "blue"]
    ax.plot(c[0, 3], c[1, 3], c[2, 3], 'X', markersize=20, color='green', alpha=0.8, label="Camera")
    ax.plot(points[:, 0], points[:, 1], points[:, 2], 'o', markersize=20, color='blue', alpha=0.8, label="Points")

    for i in range(3):
        ax.plot([c[0, 3], c[0, 3] + c[0, i]], [c[1, 3], c[1, 3] + c[1, i]], [c[2, 3], c[2, 3] + c[2, i]],
                color=cols[i], alpha=0.8, lw=3, label="Camera " + "xyz"[i] + "-axis")
    ax.set_xlabel('x_values')
    ax.set_ylabel('y_values')
    ax.set_zlabel('z_values')

    plt.title('Camera axes')
    plt.legend()

    plt.draw()
    plt.show()

    plt.gca().set_aspect("equal")
    y, x, _ = cam.dim
    plt.plot([0, 0, x, x, 0], [0, y, y, 0, 0])
    plt.scatter(*screen_coords.T)
    plt.show()

    plt.imshow(cam.snap(points))
    plt.show()

    im = np.zeros((100, 100), dtype=bool)
    v1 = np.array((20, 0))
    v2 = np.array((80, 99))

    for x in range(100):
        for y in range(100):
            im[y, x] = edge_function(np.array([x, y]), v1, v2)

    plt.imshow(im.astype(float))
    plt.show()

    fig = plt.figure(figsize=(15, 15))
    ax = fig.add_subplot(111, projection='3d')
    ax.set_xlim([-3, 3])
    ax.set_ylim([-3, 3])
    ax.set_zlim([-3, 3])

    s = Sphere()
    v = s.vertices

    ax.plot(v[:, 0], v[:, 1], v[:, 2], 'o', markersize=20, color='green', alpha=0.8, label="Camera")
    ax.set_xlabel('x_values')
    ax.set_ylabel('y_values')
    ax.set_zlabel('z_values')

    plt.title('Sphere test')
    plt.legend()

    plt.draw()
    plt.show()
