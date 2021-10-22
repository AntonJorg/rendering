import cv2
import numpy as np
from typing import List

from camera import Camera
from screen import Screen
from shapes import Shape, Cube
from transformations import translation, rotation


class Scene:
    def __init__(self,
                 camera: Camera = Camera(),
                 objects: List[Shape] = None,
                 background: List[int] = (0, 200, 0),
                 name: str = "3D - Rendering"):
        self.cam = camera
        self.objects = objects if objects is not None else [Cube()]
        self.background = background

        self.name = name
        self.frame = None

    def main_loop(self):
        running = True

        while running:

            self.frame = self.cam.raster(self.objects, self.background).repeat(6, axis=0).repeat(6, axis=1)

            cv2.imshow(self.name, self.frame)

            self.cam @ rotation(np.pi / (7 * 60), np.pi / (9 * 60), np.pi / (13 * 60))

            self.objects[0] @ translation(0.1, 0, 0)

            if cv2.waitKey(1) & 0xFF == ord('q'):
                cv2.destroyAllWindows()
                running = False
