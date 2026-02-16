package 'Infrared Thermal Imaging System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def IRWavelengthValue :> LengthValue {
		doc /* Wavelength in the infrared spectrum, typically 0.75 to 1000 micrometers */
	}

	attribute def ThermalIntensityValue :> Real {
		doc /* Relative thermal intensity measured by IR sensor */
	}

	attribute def PixelResolution {
		attribute width : Integer;
		attribute height : Integer;
	}

	item def IRRadiation {
		attribute wavelength : IRWavelengthValue;
		attribute intensity : ThermalIntensityValue;
		attribute sourceTemperature : TemperatureValue;
	}

	item def ThermalImage {
		attribute resolution : PixelResolution;
		attribute pixelData : ThermalIntensityValue[*];
		attribute captureTime : TimeValue;
		attribute ambientTemp : TemperatureValue;
	}

	item def ProcessedImage {
		attribute thermalMap : ThermalImage;
		attribute contrastEnhanced : Boolean;
		attribute noiseFiltered : Boolean;
	}

	item def ElectricalPower {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
	}

	port def IRInputPort {
		in radiation : IRRadiation;
	}

	port def ImageOutputPort {
		out image : ThermalImage;
	}

	port def ProcessedOutputPort {
		out processedImage : ProcessedImage;
	}

	port def PowerInputPort {
		in power : ElectricalPower;
	}

	port def DisplayDataPort {
		in displayData : ProcessedImage;
	}

	part def IRSensorArray {
		doc /* Focal plane array that detects infrared radiation and converts it to electrical signals */

		attribute operatingWavelength : IRWavelengthValue;
		attribute sensorResolution : PixelResolution;
		attribute operatingTemperature : TemperatureValue;
		attribute sensitivity : ThermalIntensityValue;

		port irInput : IRInputPort;
		port imageOut : ImageOutputPort;
		port powerIn : PowerInputPort;

		perform action captureIRImage {
			in incidentRadiation : IRRadiation;
			in powerSupply : ElectricalPower;
			out rawImage : ThermalImage;

			first start;
			then action detectRadiation {
				assign rawImage.resolution.width := 640;
				assign rawImage.resolution.height := 480;
			}
			then action convertToElectrical {
				assign rawImage.ambientTemp := incidentRadiation.sourceTemperature;
			}
			then action generateImageData;
			then done;
		}
	}

	part def CryogenicCooler {
		doc /* Cooling system to maintain IR sensor at cryogenic temperature for optimal sensitivity */

		attribute targetTemperature : TemperatureValue;
		attribute coolingCapacity : PowerValue;
		attribute currentTemperature : TemperatureValue;

		port powerIn : PowerInputPort;

		perform action maintainCooling {
			in powerSupply : ElectricalPower;
			in targetTemp : TemperatureValue;
			out actualTemp : TemperatureValue;

			loop {
				action measureTemperature {
					out currentMeasurement : TemperatureValue;
				}
				then decide;
					if measureTemperature.currentMeasurement > targetTemp then increaseCooling;
					if measureTemperature.currentMeasurement <= targetTemp then maintainLevel;
				action increaseCooling {
					assign actualTemp := measureTemperature.currentMeasurement - 5.0 [SI::K];
				}
				action maintainLevel {
					assign actualTemp := measureTemperature.currentMeasurement;
				}
			}
		}
	}

	part def ImageProcessor {
		doc /* Digital signal processor for enhancing thermal images and reducing noise */

		attribute processingSpeed : Real;
		attribute enhancementLevel : Real;

		port imageIn : ImageOutputPort;
		port processedOut : ProcessedOutputPort;
		port powerIn : PowerInputPort;

		perform action processImage {
			in rawImage : ThermalImage;
			out enhanced : ProcessedImage;

			first start;
			then action applyNoiseReduction {
				assign enhanced.noiseFiltered := true;
			}
			then action enhanceContrast {
				assign enhanced.contrastEnhanced := true;
			}
			then action optimizeThermalMap {
				assign enhanced.thermalMap := rawImage;
			}
			then done;
		}
	}

	part def OpticalAssembly {
		doc /* Lens system that focuses infrared radiation onto the sensor array */

		attribute focalLength : LengthValue;
		attribute apertureDiameter : LengthValue;
		attribute fieldOfView : Real;
		attribute transmissionEfficiency : Real;

		perform action focusIRRadiation {
			in incidentIR : IRRadiation;
			out focusedIR : IRRadiation;

			assign focusedIR.intensity := incidentIR.intensity * transmissionEfficiency;
			assign focusedIR.wavelength := incidentIR.wavelength;
		}
	}

	part def DisplayUnit {
		doc /* Visual display for presenting processed thermal imagery to operator */

		attribute displayResolution : PixelResolution;
		attribute refreshRate : Real;
		attribute brightness : Real;

		port displayIn : DisplayDataPort;
		port powerIn : PowerInputPort;

		perform action renderImage {
			in imageData : ProcessedImage;
			in powerSupply : ElectricalPower;

			first start;
			then action updateDisplay {
				loop {
					action refreshFrame;
					then action adjustBrightness;
				}
			}
			then done;
		}
	}

	part def PowerSupplyUnit {
		doc /* Regulated power supply providing electrical power to all system components */

		attribute outputVoltage : ElectricPotentialValue;
		attribute outputCurrent : ElectricCurrentValue;
		attribute efficiency : Real;

		perform action supplyPower {
			out power : ElectricalPower;

			assign power.voltage := outputVoltage;
			assign power.current := outputCurrent;
		}
	}

	part def InfraredImagingSystem {
		doc /* 
			Complete infrared thermal imaging system that detects thermal radiation,
			converts it to visible imagery, and displays temperature variations across
			a scene for applications including night vision, surveillance, medical
			diagnostics, and industrial inspection.
		*/

		attribute systemOperational : Boolean;
		attribute detectionRange : LengthValue;
		attribute thermalSensitivity : TemperatureValue;

		part sensor : IRSensorArray {
			attribute operatingWavelength = 10.0e-6 [SI::m];
			attribute sensorResolution : PixelResolution {
				attribute width = 640;
				attribute height = 480;
			}
			attribute operatingTemperature = 77.0 [SI::K];
			attribute sensitivity = 0.05;
		}

		part cooler : CryogenicCooler {
			attribute targetTemperature = 77.0 [SI::K];
			attribute coolingCapacity = 100.0 [SI::W];
		}

		part optics : OpticalAssembly {
			attribute focalLength = 0.1 [SI::m];
			attribute apertureDiameter = 0.05 [SI::m];
			attribute fieldOfView = 30.0;
			attribute transmissionEfficiency = 0.90;
		}

		part processor : ImageProcessor {
			attribute processingSpeed = 60.0;
			attribute enhancementLevel = 0.85;
		}

		part display : DisplayUnit {
			attribute displayResolution : PixelResolution {
				attribute width = 1920;
				attribute height = 1080;
			}
			attribute refreshRate = 60.0;
			attribute brightness = 300.0;
		}

		part powerSupply : PowerSupplyUnit {
			attribute outputVoltage = 12.0 [SI::V];
			attribute outputCurrent = 5.0 [SI::A];
			attribute efficiency = 0.92;
		}

		connection powerToCooler connect powerSupply to cooler;
		connection powerToSensor connect powerSupply to sensor;
		connection powerToProcessor connect powerSupply to processor;
		connection powerToDisplay connect powerSupply to display;
		connection sensorToProcessor connect sensor.imageOut to processor.imageIn;
		connection processorToDisplay connect processor.processedOut to display.displayIn;

		perform action thermalImagingOperation {
			doc /* Primary operational behavior of the infrared imaging system */

			first start;
			then action initializeSystem {
				action startCooling : CryogenicCooler::maintainCooling {
					in powerSupply : ElectricalPower;
					in targetTemp = 77.0 [SI::K];
					out actualTemp;
				}
				then action powerUpSensor;
			}
			then merge continuousImaging;
			then action imagingCycle {
				action captureFrame : IRSensorArray::captureIRImage {
					in incidentRadiation : IRRadiation;
					in powerSupply : ElectricalPower;
					out rawImage;
				}
				then action processFrame : ImageProcessor::processImage {
					in rawImage = captureFrame.rawImage;
					out enhanced;
				}
				then action displayFrame : DisplayUnit::renderImage {
					in imageData = processFrame.enhanced;
					in powerSupply : ElectricalPower;
				}
			}
			then decide;
				if systemOperational then continuousImaging;
				if not systemOperational then shutdownSequence;
			action shutdownSequence {
				action stopCooling;
				then action powerDown;
			}
			then done;
		}
	}

	requirement <'IR-REQ-001'> detectThermalRadiation {
		doc /* 
			The infrared imaging system shall detect thermal radiation in the
			long-wave infrared spectrum (8-14 micrometers) with a thermal
			sensitivity of at least 50 millikelvin.
		*/

		subject system : InfraredImagingSystem;

		require constraint {
			system.thermalSensitivity <= 0.05 [SI::K]
		}
	}

	requirement <'IR-REQ-002'> maintainSensorTemperature {
		doc /* 
			The cryogenic cooling system shall maintain the IR sensor array
			at 77 Kelvin with a stability of ±1 Kelvin throughout operation.
		*/

		subject coolingSystem : CryogenicCooler;

		require constraint {
			(coolingSystem.currentTemperature >= 76.0 [SI::K]) and
			(coolingSystem.currentTemperature <= 78.0 [SI::K])
		}
	}

	requirement <'IR-REQ-003'> imageResolution {
		doc /* 
			The system shall produce thermal images with a minimum resolution
			of 640x480 pixels at a frame rate of at least 30 Hz.
		*/

		subject sensorArray : IRSensorArray;

		require constraint {
			(sensorArray.sensorResolution.width >= 640) and
			(sensorArray.sensorResolution.height >= 480)
		}
	}

	requirement <'IR-REQ-004'> realTimeProcessing {
		doc /* 
			The image processor shall process and enhance thermal imagery
			in real-time with a latency not exceeding 50 milliseconds.
		*/

		subject imageProcessor : ImageProcessor;

		require constraint {
			imageProcessor.processingSpeed >= 30.0
		}
	}

	requirement <'IR-REQ-005'> opticalEfficiency {
		doc /* 
			The optical assembly shall transmit at least 85% of incident
			infrared radiation to the sensor array across the operating
			wavelength range.
		*/

		subject opticalSystem : OpticalAssembly;

		require constraint {
			opticalSystem.transmissionEfficiency >= 0.85
		}
	}

	requirement primaryMissionRequirement {
		doc /* 
			Primary mission: Provide continuous thermal imaging capability for
			detecting temperature variations and thermal signatures in complete
			darkness or through obscurants such as smoke, fog, and light foliage.
		*/

		assume constraint operatingConditions {
			doc /* System operates in ambient temperatures from -40°C to +60°C */
		}

		require detectThermalRadiation;
		require maintainSensorTemperature;
		require imageResolution;
		require realTimeProcessing;
		require opticalEfficiency;
	}
}
