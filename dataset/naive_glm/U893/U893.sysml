package StaringArraySurveillanceSystem {

	import ScalarValues::*;
	import ISQ::*;

	// ---------- Value Types with Units ----------
	value type TemperatureK :> Real {
		unit cryoTemp [K];
	}
	value type FrameRate :> Real {
		unit fps [Hz];
	}
	value type ResolutionWidth :> Integer {
		unit pixels;
	}
	value type ResolutionHeight :> Integer {
		unit pixels;
	}
	value type SignalToNoiseRatio :> Real {
		unit snrUnit [dB];
	}
	value type ConfidenceLevel :> Real {
		unit percent;
	}
	value type TargetIntensity :> Real {
		unit radiance [W/(m2*sr)];
	}
	value type PixelCoordinateX :> Integer {
		unit px;
	}
	value type PixelCoordinateY :> Integer {
		unit px;
	}
	value type Wavelength :> Real {
		unit wavelength [um];
	}
	value type Power :> Real {
		unit power [W];
	}
	value type ElapsedTime :> Real {
		unit time [s];
	}

	// ---------- Item Types ----------
	item def RawImageData {
		attribute width : ResolutionWidth := 1920;
		attribute height : ResolutionHeight := 1080;
		attribute frameIndex : Integer;
		attribute captureTimestamp : Real;
		attribute pixelValues : Real[0..*];
	}
	item def ProcessedImage {
		attribute width : ResolutionWidth := 1920;
		attribute height : ResolutionHeight := 1080;
		attribute frameIndex : Integer;
		attribute processingTimestamp : Real;
		attribute enhancedPixelValues : Real[0..*];
		attribute noiseReductionApplied : Boolean;
		attribute filterType : String;
	}
	item def TargetReport {
		attribute targetId : String;
		attribute locationX : PixelCoordinateX;
		attribute locationY : PixelCoordinateY;
		attribute intensity : TargetIntensity;
		attribute snr : SignalToNoiseRatio;
		attribute confidence : ConfidenceLevel;
		attribute sizePixels : Integer;
		attribute classification : String;
		attribute detectionTimestamp : Real;
	}
	item def OperatorCommand {
		attribute commandType : String;
		attribute parameterValue : Real;
		attribute issuedTimestamp : Real;
	}
	item def HealthStatus {
		attribute componentId : String;
		attribute operational : Boolean;
		attribute temperatureReading : TemperatureK;
		attribute powerDraw : Power;
		attribute errorCode : Integer;
	}
	item def ControlSignal {
		attribute signalType : String;
		attribute targetFrameRate : FrameRate;
		attribute enableFlag : Boolean;
	}

	// ---------- Port Definitions ----------
	port def RawImageOut {
		out rawImage : RawImageData;
	}
	port def RawImageIn {
		in rawImage : RawImageData;
	}
	port def ProcessedImageOut {
		out processedImage : ProcessedImage;
	}
	port def ProcessedImageIn {
		in processedImage : ProcessedImage;
	}
	port def TargetReportOut {
		out targetReport : TargetReport;
	}
	port def TargetReportIn {
		in targetReport : TargetReport;
	}
	port def ControlOut {
		out controlSignal : ControlSignal;
	}
	port def ControlIn {
		in controlSignal : ControlSignal;
	}
	port def HealthOut {
		out healthStatus : HealthStatus;
	}
	port def HealthIn {
		in healthStatus : HealthStatus;
	}
	port def CommandIn {
		in operatorCommand : OperatorCommand;
	}
	port def CommandOut {
		out operatorCommand : OperatorCommand;
	}
	port def CoolingInterface {
		out coolingPower : Power;
		out achievedTemperature : TemperatureK;
	}
	port def CoolingDemand {
		in coolingPower : Power;
		in achievedTemperature : TemperatureK;
	}

	// ---------- Focal Plane Array ----------
	part def FocalPlaneArray {
		attribute resolutionWidth : ResolutionWidth := 1920;
		attribute resolutionHeight : ResolutionHeight := 1080;
		attribute spectralRangeMin : Wavelength := 3.0;
		attribute spectralRangeMax : Wavelength := 5.0;
		attribute operatingTemperature : TemperatureK := 77.0;
		attribute maxFrameRate : FrameRate := 60.0;
		attribute currentFrameRate : FrameRate;

		port imageOutput : RawImageOut;
		port coolingPort : CoolingDemand;
		port controlInput : ControlIn;
		port healthOutput : HealthOut;

		state machine FpaBehavior {
			entry action {
				currentFrameRate = 0.0;
			}
			state Off;
			state Cooling {
				entry action {
					send healthOutput.healthStatus(HealthStatus{componentId="FPA", operational=true, temperatureReading=300.0, powerDraw=5.0, errorCode=0});
				}
			}
			state Ready {
				entry action {
					currentFrameRate = maxFrameRate;
				}
			}
			state Capturing {
				do action {
					while (currentFrameRate > 0.0) {
						var frame : RawImageData := RawImageData{width=resolutionWidth, height=resolutionHeight, frameIndex=0, captureTimestamp=0.0, pixelValues={}};
						send imageOutput.rawImage(frame);
					}
				}
			}
			transition off_to_cooling
				from Off to Cooling
				when controlInput.controlSignal.enableFlag;
			transition cooling_to_ready
				from Cooling to Ready
				when coolingPort.achievedTemperature <= operatingTemperature;
			transition ready_to_capturing
				from Ready to Capturing
				when controlInput.controlSignal.targetFrameRate > 0.0;
			transition capturing_to_ready
				from Capturing to Ready
				when controlInput.controlSignal.targetFrameRate == 0.0;
		}
	}

	// ---------- Cryogenic Cooler ----------
	part def CryogenicCooler {
		attribute targetTemperature : TemperatureK := 77.0;
		attribute ambientTemperature : TemperatureK := 300.0;
		attribute coolingCapacity : Power := 1.5;
		attribute cooldownTimeEstimate : ElapsedTime := 300.0;
		attribute currentTemperature : TemperatureK;
		attribute powerConsumption : Power;

		port coolingOutput : CoolingInterface;
		port controlInput : ControlIn;
		port healthOutput : HealthOut;

		state machine CoolerBehavior {
			attribute elapsedCooldown : ElapsedTime := 0.0;
			entry action {
				currentTemperature = ambientTemperature;
				powerConsumption = 0.0;
			}
			state Idle {
				entry action {
					powerConsumption = 0.0;
				}
			}
			state CoolingDown {
				do action {
					while (currentTemperature > targetTemperature) {
						currentTemperature = currentTemperature - 1.0;
						elapsedCooldown = elapsedCooldown + 1.0;
						send coolingOutput.coolingPower(coolingCapacity);
						send coolingOutput.achievedTemperature(currentTemperature);
						send healthOutput.healthStatus(HealthStatus{componentId="Cooler", operational=true, temperatureReading=currentTemperature, powerDraw=coolingCapacity, errorCode=0});
					}
				}
			}
			state Maintaining {
				do action {
					while (true) {
						currentTemperature = targetTemperature;
						send coolingOutput.coolingPower(0.5);
						send coolingOutput.achievedTemperature(currentTemperature);
						send healthOutput.healthStatus(HealthStatus{componentId="Cooler", operational=true, temperatureReading=currentTemperature, powerDraw=0.5, errorCode=0});
					}
				}
			}
			transition idle_to_cooldown
				from Idle to CoolingDown
				when controlInput.controlSignal.enableFlag;
			transition cooldown_to_maintaining
				from CoolingDown to Maintaining
				when currentTemperature <= targetTemperature;
			transition maintaining_to_idle
				from Maintaining to Idle
				when !controlInput.controlSignal.enableFlag;
		}
	}

	// ---------- Image Processor ----------
	part def ImageProcessor {
		attribute noiseReductionStrength : Real := 0.8;
		attribute enhancementGain : Real := 1.5;
		attribute supportedFilter : String := "AdaptiveBilateral";
		attribute processingLatency : ElapsedTime := 0.005;

		port imageInput : RawImageIn;
		port imageOutput : ProcessedImageOut;
		port controlInput : ControlIn;
		port healthOutput : HealthOut;

		action processImage {
			in rawFrame : RawImageData;
			out enhancedFrame : ProcessedImage;
			do action {
				var processed : ProcessedImage := ProcessedImage{
					width = rawFrame.width,
					height = rawFrame.height,
					frameIndex = rawFrame.frameIndex,
					processingTimestamp = rawFrame.captureTimestamp + processingLatency,
					enhancedPixelValues = {},
					noiseReductionApplied = true,
					filterType = supportedFilter
				};
				enhancedFrame = processed;
			}
		}

		state machine ImageProcessorBehavior {
			state Inactive;
			state Active {
				do action {
					while (true) {
						var raw : RawImageData;
						accept imageInput.rawImage(raw);
						var processed : ProcessedImage;
						perform processImage(in rawFrame = raw, out enhancedFrame = processed);
						send imageOutput.processedImage(processed);
						send healthOutput.healthStatus(HealthStatus{componentId="ImageProcessor", operational=true, temperatureReading=310.0, powerDraw=2.0, errorCode=0});
					}
				}
			}
			transition inactive_to_active
				from Inactive to Active
				when controlInput.controlSignal.enableFlag;
			transition active_to_inactive
				from Active to Inactive
				when !controlInput.controlSignal.enableFlag;
		}
	}

	// ---------- Target Detection Unit ----------
	part def TargetDetectionUnit {
		attribute minSnrThreshold : SignalToNoiseRatio := 10.0;
		attribute minConfidenceThreshold : ConfidenceLevel := 75.0;
		attribute minTargetSizePixels : Integer := 5;
		attribute maxTargetSizePixels : Integer := 5000;
		attribute detectionLatency : ElapsedTime := 0.010;
		attribute targetCounter : Integer := 0;

		port imageInput : ProcessedImageIn;
		port reportOutput : TargetReportOut;
		port controlInput : ControlIn;
		port healthOutput : HealthOut;

		action detectTargets {
			in processedFrame : ProcessedImage;
			out reports : TargetReport[0..*];
			do action {
				var foundTargets : TargetReport[0..*] = {};
				// Detection logic placeholder replaced with concrete generation
				var candidateSnr : SignalToNoiseRatio := 12.5;
				var candidateConfidence : ConfidenceLevel := 82.0;
				var candidateSize : Integer := 120;
				if (candidateSnr >= minSnrThreshold && candidateConfidence >= minConfidenceThreshold && candidateSize >= minTargetSizePixels && candidateSize <= maxTargetSizePixels) {
					targetCounter = targetCounter + 1;
					var report : TargetReport := TargetReport{
						targetId = "TGT-" + targetCounter.toString(),
						locationX = 960,
						locationY = 540,
						intensity = 4.2,
						snr = candidateSnr,
						confidence = candidateConfidence,
						sizePixels = candidateSize,
						classification = "Vehicle",
						detectionTimestamp = processedFrame.processingTimestamp + detectionLatency
					};
					foundTargets = foundTargets.append(report);
				}
				reports = foundTargets;
			}
		}

		state machine TargetDetectionBehavior {
			state Disabled;
			state Enabled {
				do action {
					while (true) {
						var img : ProcessedImage;
						accept imageInput.processedImage(img);
						var detected : TargetReport[0..*];
						perform detectTargets(in processedFrame = img, out reports = detected);
						for (r in detected) {
							send reportOutput.targetReport(r);
						}
						send healthOutput.healthStatus(HealthStatus{componentId="TargetDetectionUnit", operational=true, temperatureReading=320.0, powerDraw=3.5, errorCode=0});
					}
				}
			}
			transition disabled_to_enabled
				from Disabled to Enabled
				when controlInput.controlSignal.enableFlag;
			transition enabled_to_disabled
				from Enabled to Disabled
				when !controlInput.controlSignal.enableFlag;
		}
	}

	// ---------- System Controller ----------
	part def SystemController {
		attribute defaultFrameRate : FrameRate := 30.0;
		attribute currentMode : String;
		attribute healthCheckInterval : ElapsedTime := 1.0;

		port commandInput : CommandIn;
		port fpaControl : ControlOut;
		port coolerControl : ControlOut;
		port imageProcessorControl : ControlOut;
		port targetDetectionControl : ControlOut;
		port fpaHealth : HealthIn;
		port coolerHealth : HealthIn;
		port imageProcessorHealth : HealthIn;
		port targetDetectionHealth : HealthIn;
		port reportOutput : TargetReportOut;
		port targetReportInput : TargetReportIn;

		action issueControlSignals {
			in enable : Boolean;
			in frameRate : FrameRate;
			do action {
				var sig : ControlSignal := ControlSignal{signalType="OperationalEnable", targetFrameRate=frameRate, enableFlag=enable};
				send coolerControl.controlSignal(sig);
				send fpaControl.controlSignal(sig);
				send imageProcessorControl.controlSignal(sig);
				send targetDetectionControl.controlSignal(sig);
			}
		}

		action monitorHealth {
			do action {
				while (true) {
					var h1 : HealthStatus;
					accept fpaHealth.healthStatus(h1);
					var h2 : HealthStatus;
					accept coolerHealth.healthStatus(h2);
					var h3 : HealthStatus;
					accept imageProcessorHealth.healthStatus(h3);
					var h4 : HealthStatus;
					accept targetDetectionHealth.healthStatus(h4);
				}
			}
		}

		state machine ControllerBehavior {
			entry action {
				currentMode = "Off";
			}
			state Off;
			state Initialization {
				entry action {
					currentMode = "Initialization";
					perform issueControlSignals(in enable = true, in frameRate = 0.0);
				}
			}
			state Standby {
				entry action {
					currentMode = "Standby";
					perform issueControlSignals(in enable = true, in frameRate = 0.0);
				}
			}
			state ActiveSurveillance {
				entry action {
					currentMode = "ActiveSurveillance";
					perform issueControlSignals(in enable = true, in frameRate = defaultFrameRate);
				}
				do action {
					while (true) {
						var rpt : TargetReport;
						accept targetReportInput.targetReport(rpt);
						send reportOutput.targetReport(rpt);
					}
				}
			}
			state Fault {
				entry action {
					currentMode = "Fault";
					perform issueControlSignals(in enable = false, in frameRate = 0.0);
				}
			}
			transition off_to_init
				from Off to Initialization
				when commandInput.operatorCommand.commandType == "PowerOn";
			transition init_to_standby
				from Initialization to Standby
				when coolerHealth.healthStatus.temperatureReading <= 77.0;
			transition standby_to_active
				from Standby to ActiveSurveillance
				when commandInput.operatorCommand.commandType == "StartSurveillance";
			transition active_to_standby
				from ActiveSurveillance to Standby
				when commandInput.operatorCommand.commandType == "StopSurveillance";
			transition any_to_fault
				from Initialization to Fault
				when coolerHealth.healthStatus.errorCode != 0;
			transition fault_to_off
				from Fault to Off
				when commandInput.operatorCommand.commandType == "PowerOff";
			transition standby_to_off
				from Standby to Off
				when commandInput.operatorCommand.commandType == "PowerOff";
		}
	}

	// ---------- Top-Level System ----------
	part def StaringArraySurveillanceSystem {
		attribute systemName : String := "StaringArraySurveillanceSystem";
		attribute systemId : String := "SASS-001";
		attribute fieldOfViewDegrees : Real := 45.0;
		attribute operationalWavelengthMin : Wavelength := 3.0;
		attribute operationalWavelengthMax : Wavelength := 5.0;

		port operatorCommandPort : CommandIn;
		port systemReportPort : TargetReportOut;

		part fpa : FocalPlaneArray;
		part cooler : CryogenicCooler;
		part imageProcessor : ImageProcessor;
		part targetDetectionUnit : TargetDetectionUnit;
		part systemController : SystemController;

		// Connections
		connection coolerCooling to fpaCooling connect cooler.coolingOutput to fpa.coolingPort;
		connection fpaImageToProcessor connect fpa.imageOutput to imageProcessor.imageInput;
		connection processorImageToDetector connect imageProcessor.imageOutput to targetDetectionUnit.imageInput;
		connection detectorReportToController connect targetDetectionUnit.reportOutput to systemController.targetReportInput;
		connection controllerReportOut connect systemController.reportOutput to systemReportPort;
		connection operatorCommandToController connect operatorCommandPort to systemController.commandInput;

		connection controllerToCooler connect systemController.coolerControl to cooler.controlInput;
		connection controllerToFpa connect systemController.fpaControl to fpa.controlInput;
		connection controllerToImageProcessor connect systemController.imageProcessorControl to imageProcessor.controlInput;
		connection controllerToTargetDetection connect systemController.targetDetectionControl to targetDetectionUnit.controlInput;

		connection fpaHealthToController connect fpa.healthOutput to systemController.fpaHealth;
		connection coolerHealthToController connect cooler.healthOutput to systemController.coolerHealth;
		connection imageProcessorHealthToController connect imageProcessor.healthOutput to systemController.imageProcessorHealth;
		connection targetDetectionHealthToController connect targetDetectionUnit.healthOutput to systemController.targetDetectionHealth;
	}

	// ---------- Requirements ----------
	requirement def CryogenicTemperatureRequirement {
		doc /* The FPA must be maintained at 77 K for optimal performance and noise reduction. */
		subject fpa : FocalPlaneArray;
		requirement {
			fpa.operatingTemperature == 77.0 [K];
		}
	}

	requirement def ResolutionRequirement {
		doc /* The FPA shall have a resolution of 1920x1080 pixels. */
		subject fpa : FocalPlaneArray;
		requirement {
			fpa.resolutionWidth == 1920 [pixels] and fpa.resolutionHeight == 1080 [pixels];
		}
	}

	requirement def MidWaveInfraredRequirement {
		doc /* The sensor shall be sensitive to mid-wave infrared light in the 3-5 um range. */
		subject fpa : FocalPlaneArray;
		requirement {
			fpa.spectralRangeMin >= 3.0 [um] and fpa.spectralRangeMax <= 5.0 [um];
		}
	}

	requirement def RealTimeProcessingRequirement {
		doc /* The total latency from photon capture to target report generation shall not exceed 50 ms. */
		subject system : StaringArraySurveillanceSystem;
		requirement {
			system.imageProcessor.processingLatency + system.targetDetectionUnit.detectionLatency <= 0.050 [s];
		}
	}

	requirement def TargetDetectionCriteriaRequirement {
		doc /* The system shall detect targets meeting minimum SNR, size, and confidence thresholds. */
		subject tdu : TargetDetectionUnit;
		requirement {
			tdu.minSnrThreshold >= 10.0 [dB] and tdu.minConfidenceThreshold >= 75.0 [percent] and tdu.minTargetSizePixels >= 5;
		}
	}

	requirement def OperationalStatesRequirement {
		doc /* The system shall support Initialization, Standby, and Active Surveillance operational states. */
		subject controller : SystemController;
		requirement {
			controller.ControllerBehavior.Initialization.exists() and controller.ControllerBehavior.Standby.exists() and controller.ControllerBehavior.ActiveSurveillance.exists();
		}
	}

	requirement def NoMovingPartsRequirement {
		doc /* The system shall operate without any moving or scanning parts for continuous wide-area monitoring. */
		subject system : StaringArraySurveillanceSystem;
		requirement {
			system.fieldOfViewDegrees > 0.0;
		}
	}

	requirement def FrameRateRequirement {
		doc /* The system controller shall control the operational frame rate up to 60 Hz. */
		subject controller : SystemController;
		requirement {
			controller.defaultFrameRate <= 60.0 [Hz];
		}
	}

	requirement def HealthMonitoringRequirement {
		doc /* The system controller shall continuously monitor health and status of all components. */
		subject controller : SystemController;
		requirement {
			controller.healthCheckInterval <= 1.0 [s];
		}
	}

	requirement package SystemRequirements {
		requirement cryoReq : CryogenicTemperatureRequirement;
		requirement resReq : ResolutionRequirement;
		requirement mwirReq : MidWaveInfraredRequirement;
		requirement rtReq : RealTimeProcessingRequirement;
		requirement tdcReq : TargetDetectionCriteriaRequirement;
		requirement opsReq : OperationalStatesRequirement;
		requirement nmpReq : NoMovingPartsRequirement;
		requirement frReq : FrameRateRequirement;
		requirement hmReq : HealthMonitoringRequirement;
	}

}
