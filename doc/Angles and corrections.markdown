Title: Angles and corrections
CSS: doc_style.css
Author: Jean-Olivier Irisson

# Dealing with angles and circular corrections in DISCUS

	(c) Copyright 2009 J-O Irisson, C Paris. GNU Free Documentation License

## Measure of angles

The angles are measures either by the numerical compass or by converting positions from cardinal to polar coordinates using `car2pol` in `lib_circular_stat.R`. `car2pol` gives results from the horizontal in counter clockwise direction (i.e. trigonometric convention) but these can easily be converted to bearings using `conversion.circular` in the `circular` package for R.

Now rotation can be viewed from above or from below, while the angles measured are actually the same in both directions, so there is a difference between angles measured and real bearings when viewed form below. When viewed from below, the East is actually on the _left_ side of the picture.

![Measured Angles](images/measured_angles.png)


## Correction for the rotation of the aquarium

Let us consider the following scenario: a larva is present on the East side of the aquarium and follows the Eastern direction all the time; the instrument starts with the top of the picture exactly North and then rotates 45º to the West (so the compass needle appears to move 45º to the E compared the initial position).

Before the rotation, we can check that from above, the larva to the east is on the right side of the picture while, from underneath, the larva appears to be on the _left_ side of the picture. This is another representation of what we jus saw above.

![Correction Rotation](images/correction_rotation.png)

So, in both cases, the correction is equal to `-observedRotation`.


## Angle between the numerical compass an the camera

Until now, we have been assuming that angles are measured from the top of the frame, i.e. the top of the camera. However, the numerical compass. when it is used, is actually pointing to the left of the camera. For simplicity, we want to get, at each time frame, the bearing of the top of the picture (i.e. the top of the camera) rather than the bearing of the "left of the picture".

For that we use the calibration pictures, taken while the camera is on top and looks down on a physical compass. When the top of the picture points North, the numerical reading is ~270º, which is consistent with the compass pointing to the left of the camera (A below).

![Camera Compass Angle](images/camera-compass_angle.png)

To get a precise estimate we take a picture of a scene where the compass points in another direction (B above). We measure the angle between the top of the picture and the compass needle in ImageJ and, by doing so, measure the real bearing of the top of the frame 360-175 = 185 here. Then we compare it with the numerical compass bearing (100 here). This allows us to deduce that the angle between the top of the camera and the aim of the compass is 85 deg.

Now the sign of the correction depends on where we look at the picture from. Let us consider that the top of the camera is pointing North, its bearing should be 0.

* when the camera looks from the top, the numerical compass reading is 275º, so we need to _add_ 85º to the numerical bearing to get the bearing of the top of the frame.

* when the camera looks from the below, the numerical compass reading is 85º, so we need to _subtract_ 85º to the numerical bearing to get the bearing of the top of the frame.


## Account for the fact that we look from below

After these two corrections, the top of every frame points North. However the E is still on the left of the picture when looking from below. It needs to be put on the right, as in regular geographic bearings.

Angles are measured from the top in clockwise direction. So a point on the horizontal left of the picture (i.e. due East) would have an angle of 270º instead of 90º. A point at 45º on the right (i.e. North-West) would have a bearing of 45º instead of 315º. But a point at the bottom of the picture would have a correct bearing of 180º. So the correction is not just adding or subtracting 180º. We actually need to invert the direction of measurement of the angles, i.e. pretend that the positions angles are measured counter-clockwise and convert them to their clockwise equivalent.

This will compute the symmetry that's needed to put the East to the right.


## Summary

The steps involved in getting the positons of the larva in cardinal coordinates are therefore:

1. Measure/get compass readings in degrees, clockwise direction, from the top of the picture.

	* for manual detection, put positions of the North in polar coordinates and convert the angular system from trigonometric to bearings

	* for numerical bearings, correct for the camera/compass angle. I.e.

		* from above: `numericalBearing + deviation`

		* from below: `numericalBearing - deviation`

2. Measure larval positions in degrees, clockwise direction, from the top of the picture. Same procedure as for the manual compass above: `car2pol` and then `conversion.circular`.

3. Correct for the rotation of the compass: on every frame, compute `angleLarva - angleCompass`.

4. Switch the East to the correct location (on the right).

	* from above: do nothing, everything is good already

	* from below: invert direction of measurement of angles _and_ compass
