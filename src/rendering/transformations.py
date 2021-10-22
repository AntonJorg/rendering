import numpy as np


def yaw(theta: float):
    """
    Create a rotation matrix rotating points theta radians around the z-axis.

    :param theta: number of radians to rotate
    :return: rotation matrix (4x4 ndarray)
    """
    return np.array([
        [np.cos(theta), -np.sin(theta), 0, 0],
        [np.sin(theta),  np.cos(theta), 0, 0],
        [0,              0,             1, 0],
        [0,              0,             0, 1]
    ])


def pitch(theta: float):
    """
    Create a rotation matrix rotating points theta radians around the y-axis.

    :param theta: number of radians to rotate
    :return: rotation matrix (4x4 ndarray)
    """
    return np.array([
        [np.cos(theta),  0, np.sin(theta), 0],
        [0,              1, 0,             0],
        [-np.sin(theta), 0, np.cos(theta), 0],
        [0,              0, 0,             1]
    ])


def roll(theta: float):
    """
    Create a rotation matrix rotating points theta radians around the x-axis.

    :param theta: number of radians to rotate
    :return: rotation matrix (4x4 ndarray)
    """
    return np.array([
        [1, 0,              0,             0],
        [0, np.cos(theta), -np.sin(theta), 0],
        [0, np.sin(theta),  np.cos(theta), 0],
        [0, 0,              0,             1]
    ])


def rotation(alpha: float, beta: float, gamma: float):
    """
    Create a rotation matrix rotating points alpha radians around the x-axis, beta radians around the y-axis,
    and gamma radians around the z-axis, in that order.

    :param alpha: number of radians to rotate around the x-axis
    :param beta: number of radians to rotate around the y-axis
    :param gamma: number of radians to rotate around the z-axis
    :return: rotation matrix (4x4 ndarray)
    """
    return yaw(gamma) @ pitch(beta) @ roll(alpha)


def translation(x, y, z):
    """
    # TODO: Write docstring
    :param x:
    :param y:
    :param z:
    :return:
    """
    return np.array([
        [1, 0, 0, x],
        [0, 1, 0, y],
        [0, 0, 1, z],
        [0, 0, 0, 1]
    ])
