import math

h = 6.626e-34
c = 2.9979e8

print("Part 1")

watts = 25
efficiency = 0.2

wavelength = 500e-9

answer = watts * efficiency * wavelength / (h * c)

print(answer)

print("Part 2")

voltage = 2.4
amperage = 0.7

diameter = 0.01
radius = diameter / 2

flux = voltage * amperage

intensity = flux / (4 * math.pi)

area = 4 * math.pi * radius * radius
exitance = flux / area
emitted_energy_5_mins = flux * 5 * 60

print(f"Flux: {flux}")
print(f"Intensity: {intensity}")
print(f"Exitance: {exitance}")
print(f"Emitted energy (5min): {emitted_energy_5_mins}")

print("Part 3")

pupil_diameter = 0.006
pupil_radius = pupil_diameter / 2
pupil_area = 2 * math.pi * pupil_radius * pupil_radius

distance = 1

pupil_irradiance = flux * pupil_area / (4 * math.pi)