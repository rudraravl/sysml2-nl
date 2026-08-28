package ThermalCameraSystem {
	private import ScalarValues::*;

	item def InfraredRadiation;
	item def RawThermalData;
	item def ProcessedImage;
	item def ElectricalPower;
	item def CoolingSignal;

	attribute def Temperature :> Real;

	port def IRInputPort {
		in item ir : InfraredRadiation;
	}
	port def IROutputPort {
		out item ir : InfraredRadiation;
	}
	port def RawDataOutputPort {
		out item rawThermalData : RawThermalData;
	}
	port def RawDataInputPort {
		in item rawThermalData : RawThermalData;
	}
	port def ImageOutputPort {
		out item processedImage : ProcessedImage;
	}
	port def ImageInputPort {
		in item processedImage : ProcessedImage;
	}
	port def PowerOutputPort {
		out item power : ElectricalPower;
	}
	port def PowerInputPort {
		in item power : ElectricalPower;
	}
	port def CoolingOutputPort {
		out item cooling : CoolingSignal;
	}
	port def CoolingInputPort {
		in item cooling : CoolingSignal;
	}

	part def OpticalAssembly {
		port irInput : IRInputPort;
		port irOutput : IROutputPort;
	}

	part def InfraredSensorArray {
		attribute resolutionX : Integer = 640;
		attribute resolutionY : Integer = 480;
		attribute operatingTemperature : Temperature = 77;

		port irInput : IRInputPort;
		port dataOutput : RawDataOutputPort;
		port coolingInput : CoolingInputPort;
		port powerInput : PowerInputPort;
	}

	part def CryogenicCooler {
		attribute targetTemperature : Temperature = 77;

		port powerInput : PowerInputPort;
		port coolingOutput : CoolingOutputPort;
	}

	part def ImageProcessor {
		port powerInput : PowerInputPort;
		port dataInput : RawDataInputPort;
		port imageOutput : ImageOutputPort;
	}

	part def DisplayUnit {
		port powerInput : PowerInputPort;
		port imageInput : ImageInputPort;
	}

	part def PowerSupplyUnit {
		port powerOutput : PowerOutputPort;
	}

	action def CaptureThermalData {
		in item ir : InfraredRadiation;
		out item rawThermalData : RawThermalData;
	}

	action def ProcessThermalData {
		in item rawThermalData : RawThermalData;
		out item processedImage : ProcessedImage;
	}

	action def DisplayImageAction {
		in item processedImage : ProcessedImage;
	}

	action def ThermalImagingCycle {
		in item ir : InfraredRadiation;

		action capture : CaptureThermalData {
			in item ir = ThermalImagingCycle::ir;
			out item rawThermalData;
		}
		flow from capture.rawThermalData to process.rawThermalData;
		action process : ProcessThermalData {
			in item rawThermalData;
			out item processedImage;
		}
		flow from process.processedImage to display.processedImage;
		action display : DisplayImageAction {
			in item processedImage;
		}
	}

	part def ThermalCamera {
		port environmentPort : IRInputPort;
		in item ir : InfraredRadiation via environmentPort;
		attribute standby : Boolean = false;

		part powerSupply : PowerSupplyUnit;
		part opticalAssembly : OpticalAssembly;
		part sensorArray : InfraredSensorArray;
		part cooler : CryogenicCooler;
		part processor : ImageProcessor;
		part display : DisplayUnit;

		connect environmentPort to opticalAssembly.irInput;
		connect opticalAssembly.irOutput to sensorArray.irInput;
		connect cooler.coolingOutput to sensorArray.coolingInput;
		connect sensorArray.dataOutput to processor.dataInput;
		connect processor.imageOutput to display.imageInput;

		connect powerSupply.powerOutput to cooler.powerInput;
		connect powerSupply.powerOutput to sensorArray.powerInput;
		connect powerSupply.powerOutput to processor.powerInput;
		connect powerSupply.powerOutput to display.powerInput;

		state machine operation {
			state Off;
			state Initializing;
			state Ready;
			state Operating {
				do action thermalImaging : ThermalImagingCycle {
					in item ir = ThermalCamera::ir;
				}
			}

			transition off_to_init : Off to Initializing;
			transition init_to_ready : Initializing to Ready when sensorArray.operatingTemperature <= cooler.targetTemperature;
			transition ready_to_operating : Ready to Operating;
			transition operating_to_ready : Operating to Ready when standby;
		}
	}

	requirement def ThermalCameraRequirement {
		subject camera : ThermalCamera;

		requirement detectHeatSignatures {
			doc /* The system shall detect heat signatures from infrared radiation. */
		}

		requirement operateInDarkness {
			doc /* The system shall allow users to see temperature variations in a scene, even in complete darkness or through obscurants like smoke and fog. */
		}

		requirement sensorCooling {
			doc /* The cryogenic cooler shall maintain the sensor at its optimal operating temperature of 77 Kelvin. */
			constraint { camera.sensorArray.operatingTemperature == 77 }
		}

		requirement sensorResolution {
			doc /* The infrared sensor array shall have a 640x480 pixel resolution. */
			constraint { camera.sensorArray.resolutionX == 640 and camera.sensorArray.resolutionY == 480 }
		}

		requirement realTimeProcessing {
			doc /* The image processor shall enhance the image in real-time, applying noise reduction and contrast adjustments. */
		}

		requirement displayImage {
			doc /* The final processed image shall be shown to the operator on a high-resolution display unit. */
		}

		requirement powerDistribution {
			doc /* A central power supply unit shall provide regulated electrical power to all components. */
		}
	}
}
