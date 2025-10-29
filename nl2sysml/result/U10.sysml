// Model a smart home system that is able to turn on the lights.
package 'SmartHomeSystemModel' {
	private import ScalarValues::*;

	attribute def LightState : Boolean;

	part def Light {
		attribute state : LightState;
	}

	part def LightController {
		ref controlsLight : Light;
	}

	part def SmartHomeSystem {
		part controller : LightController;
		part livingRoomLight : Light;

		redefines controller.controlsLight = livingRoomLight;

		action def turnOnLight {
			in targetLight : Light;
		}

		controller.perform turnOnLight {
			in targetLight = livingRoomLight;
			livingRoomLight.state = true;
		}
	}
}
