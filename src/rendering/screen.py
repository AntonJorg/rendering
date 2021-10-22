import cv2
import numpy as np
import time
from datetime import datetime, timedelta

from camera import Camera
from shapes import Cube
from transformations import rotation


class Screen:
    def __init__(self, width=720, height=480, fps=60,
                 name="3D-Rendering",
                 background=(225, 210, 230)):
        self.width = width
        self.height = height
        self.fps = fps
        self.name = name

        self.background = np.array(background)

        self.frame = np.zeros((self.height, self.width, 3))
        self.frame[:, :] = self.background

    def main_loop(self):
        running = True
        curr_time = datetime.now()

        # TODO: REMOVE THIS, ONLY FOR TESTING
        cam = Camera

        cam = Camera(pos=(0, 5, -5), rot=(np.pi/4, 0, 0), dim=(72, 128, 3), f=1)
        cube = Cube(length=2)
        cube2 = Cube(pos=(1.5, 0, 0))

        while running:
            try:
                self.frame = cam.raster([cube, cube2], self.background).repeat(6, axis=0).repeat(6, axis=1)

                cv2.imshow(self.name, self.frame)

                cam @ rotation(0, np.pi / (16 * self.fps), np.pi / (4 * self.fps))

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break

                sleepy_time = (curr_time + timedelta(seconds=1 / self.fps) - datetime.now()).total_seconds()
                time.sleep(sleepy_time if sleepy_time > 0 else 0)
                curr_time = datetime.now()

            except KeyboardInterrupt:
                cv2.destroyAllWindows()
                running = False
