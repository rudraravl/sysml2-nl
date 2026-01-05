package 'Gastric Balloon System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientID;
	attribute def DeploymentCommand;
	attribute def RemovalCommand;
	attribute def SafetyAlert;
	attribute def MaintenanceCheck;
	
	item def SalineSolution {
		attribute volume : ISQ::VolumeValue;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute concentration : Real;
	}
	
	port def FluidPort {
		in flow salineIn : SalineSolution;
		out flow salineOut : SalineSolution;
	}
	
	port def SensorPort {
		out flow pressureReading : ISQ::PressureValue;
		out flow volumeReading : ISQ::VolumeValue;
		out flow temperatureReading : ISQ::ThermodynamicTemperatureValue;
	}
	
	port def ControlPort {
		in flow commandSignal : Boolean;
		out flow statusSignal : Boolean;
	}
	
	part def IntragastricBalloon {
		attribute balloonID : String;
		attribute nominalVolume : ISQ::VolumeValue;
		attribute maxPressure : ISQ::PressureValue;
		attribute currentVolume : ISQ::VolumeValue;
		attribute currentPressure : ISQ::PressureValue;
		attribute materialIntegrity : Real;
		attribute isDeployed : Boolean;
		
		port inflationPort : FluidPort;
		port deflationPort : FluidPort;
		port sensorPort : SensorPort;
	}
	
	part def CatheterSystem {
		attribute catheterDiameter : ISQ::LengthValue;
		attribute catheterLength : ISQ::LengthValue;
		
		port proximalPort : FluidPort;
		port distalPort : FluidPort;
	}
	
	part def InflationPump {
		attribute maxFlowRate : Real;
		attribute salineReservoirCapacity : ISQ::VolumeValue;
		attribute currentReservoirLevel : ISQ::VolumeValue;
		
		port fluidOutPort : FluidPort;
		port controlPort : ControlPort;
	}
	
	part def DeflationPump {
		attribute maxExtractionRate : Real;
		attribute wasteCapacity : ISQ::VolumeValue;
		
		port fluidInPort : FluidPort;
		port controlPort : ControlPort;
	}
	
	part def MonitoringUnit {
		attribute pressureAlarmThreshold : ISQ::PressureValue;
		attribute volumeAlarmThreshold : ISQ::VolumeValue;
		attribute temperatureAlarmThreshold : ISQ::ThermodynamicTemperatureValue;
		attribute monitoringInterval : ISQ::TimeValue;
		
		port sensorInputPort : SensorPort;
		port alertOutputPort;
	}
	
	part def ControlUnit {
		attribute treatmentDuration : ISQ::TimeValue;
		attribute deploymentTimestamp : String;
		attribute scheduledRemovalDate : String;
		
		port inflationControlPort : ControlPort;
		port deflationControlPort : ControlPort;
		port monitoringControlPort;
	}
	
	requirement def SafetyRequirement {
		doc /* The gastric balloon system shall operate within safe pressure and volume limits to prevent balloon rupture and patient harm. */
		
		require constraint pressureSafety {
			doc /* Balloon internal pressure shall not exceed maximum rated pressure during operation. */
		}
		
		require constraint volumeSafety {
			doc /* Balloon volume shall remain within specified limits to prevent gastric obstruction. */
		}
		
		require constraint biocompatibility {
			doc /* All materials in contact with gastric environment shall be biocompatible. */
		}
	}
	
	requirement def FunctionalRequirement {
		doc /* The gastric balloon system shall reduce gastric capacity to promote satiety and weight loss. */
		
		require constraint stomachOccupancy {
			doc /* Balloon shall occupy 400-700 mL of gastric volume when fully deployed. */
		}
		
		require constraint deploymentReliability {
			doc /* Balloon deployment shall achieve target volume within 15 minutes. */
		}
		
		require constraint removalCapability {
			doc /* Balloon shall be completely deflatable and removable via endoscopy. */
		}
		
		require constraint treatmentDuration {
			doc /* Balloon shall maintain integrity for minimum 6-month treatment period. */
		}
	}
	
	requirement def PerformanceRequirement {
		doc /* The gastric balloon system shall achieve clinically significant weight loss outcomes. */
		
		require constraint weightLossEfficacy {
			doc /* System shall support 10-15% total body weight loss over 6-month period. */
		}
		
		require constraint patientCompliance {
			doc /* System design shall minimize patient discomfort to support treatment adherence. */
		}
	}
	
	action def MonitorPressure {
		in currentPressure : ISQ::PressureValue;
		in maxPressure : ISQ::PressureValue;
		out pressureStatus : Boolean;
		out alert : SafetyAlert;
		
		then decide;
			if currentPressure > maxPressure then raiseAlert;
			if currentPressure <= maxPressure then normalOperation;
		
		action raiseAlert {
			assign pressureStatus := false;
		}
		
		action normalOperation {
			assign pressureStatus := true;
		}
	}
	
	action def MonitorVolume {
		in currentVolume : ISQ::VolumeValue;
		in minVolume : ISQ::VolumeValue;
		in maxVolume : ISQ::VolumeValue;
		out volumeStatus : Boolean;
		out alert : SafetyAlert;
		
		then decide;
			if currentVolume < minVolume or currentVolume > maxVolume then raiseAlert;
			if currentVolume >= minVolume and currentVolume <= maxVolume then normalOperation;
		
		action raiseAlert {
			assign volumeStatus := false;
		}
		
		action normalOperation {
			assign volumeStatus := true;
		}
	}
	
	action def InflateBalloon {
		in targetVolume : ISQ::VolumeValue;
		in inflationRate : Real;
		in salineSupply : SalineSolution;
		out finalVolume : ISQ::VolumeValue;
		out finalPressure : ISQ::PressureValue;
		out inflationComplete : Boolean;
		
		private attribute volumeDelivered : ISQ::VolumeValue := 0.0 [SI::mL];
		private attribute stepVolume : ISQ::VolumeValue := 50.0 [SI::mL];
		
		first start;
		then merge inflationLoop;
		
		action checkProgress {
			then decide;
				if volumeDelivered < targetVolume then deliverSaline;
				if volumeDelivered >= targetVolume then completeInflation;
		}
		
		action deliverSaline {
			assign volumeDelivered := volumeDelivered + stepVolume;
		}
		then inflationLoop;
		
		action completeInflation {
			assign finalVolume := volumeDelivered;
			assign inflationComplete := true;
		}
		then done;
	}
	
	action def DeflateBalloon {
		in currentVolume : ISQ::VolumeValue;
		in deflationRate : Real;
		out removedVolume : ISQ::VolumeValue;
		out deflationComplete : Boolean;
		
		private attribute volumeRemoved : ISQ::VolumeValue := 0.0 [SI::mL];
		private attribute stepVolume : ISQ::VolumeValue := 50.0 [SI::mL];
		
		first start;
		then merge deflationLoop;
		
		action checkProgress {
			then decide;
				if volumeRemoved < currentVolume then extractSaline;
				if volumeRemoved >= currentVolume then completeDeflation;
		}
		
		action extractSaline {
			assign volumeRemoved := volumeRemoved + stepVolume;
		}
		then deflationLoop;
		
		action completeDeflation {
			assign removedVolume := volumeRemoved;
			assign deflationComplete := true;
		}
		then done;
	}
	
	action def DeployBalloon {
		in targetVolume : ISQ::VolumeValue;
		in maxPressure : ISQ::PressureValue;
		in inflationRate : Real;
		out deploymentSuccess : Boolean;
		
		first start;
		
		then action positionBalloon {
			doc /* Position deflated balloon in stomach via endoscopic guidance. */
		}
		
		then action initiateInflation : InflateBalloon {
			in targetVolume = DeployBalloon::targetVolume;
			in inflationRate = DeployBalloon::inflationRate;
			out finalVolume;
			out finalPressure;
			out inflationComplete;
		}
		
		then merge monitoringLoop;
		
		then action performMonitoring {
			action checkPressure : MonitorPressure {
				in currentPressure = initiateInflation.finalPressure;
				in maxPressure = DeployBalloon::maxPressure;
				out pressureStatus;
				out alert;
			}
			
			action checkVolume : MonitorVolume {
				in currentVolume = initiateInflation.finalVolume;
				in minVolume = 400.0 [SI::mL];
				in maxVolume = 700.0 [SI::mL];
				out volumeStatus;
				out alert;
			}
		}
		
		then decide;
			if performMonitoring.checkPressure.pressureStatus == true 
				and performMonitoring.checkVolume.volumeStatus == true 
				then confirmDeployment;
			if performMonitoring.checkPressure.pressureStatus == false 
				or performMonitoring.checkVolume.volumeStatus == false 
				then emergencyDeflate;
		
		action confirmDeployment {
			assign deploymentSuccess := true;
		}
		then done;
		
		action emergencyDeflate : DeflateBalloon {
			in currentVolume = initiateInflation.finalVolume;
			in deflationRate = 100.0;
			out removedVolume;
			out deflationComplete;
		}
		then assign deploymentSuccess := false;
		then done;
	}
	
	action def RemoveBalloon {
		in currentVolume : ISQ::VolumeValue;
		in deflationRate : Real;
		out removalSuccess : Boolean;
		
		first start;
		
		then action controlledDeflation : DeflateBalloon {
			in currentVolume = RemoveBalloon::currentVolume;
			in deflationRate = RemoveBalloon::deflationRate;
			out removedVolume;
			out deflationComplete;
		}
		
		then action verifyDeflation {
			then decide;
				if controlledDeflation.deflationComplete == true then extractBalloon;
				if controlledDeflation.deflationComplete == false then retryDeflation;
		}
		
		action extractBalloon {
			doc /* Extract deflated balloon via endoscopic retrieval. */
			assign removalSuccess := true;
		}
		then done;
		
		action retryDeflation : DeflateBalloon {
			in currentVolume = controlledDeflation.removedVolume;
			in deflationRate = RemoveBalloon::deflationRate;
			out removedVolume;
			out deflationComplete;
		}
		then assign removalSuccess := false;
		then done;
	}
	
	state def BalloonLifecycle {
		entry; then stored;
		
		state stored {
			doc /* Balloon is sterile-packaged and stored prior to deployment. */
			accept deployCmd : DeploymentCommand;
			then positioning;
		}
		
		state positioning {
			doc /* Balloon is being positioned in stomach via endoscopy. */
			then inflating;
		}
		
		state inflating {
			doc /* Balloon is being filled with saline solution. */
			do action inflate : InflateBalloon;
			then deployed;
		}
		
		state deployed {
			doc /* Balloon is fully inflated and occupying gastric space. */
			do action continuousMonitoring {
				action monitorPressure : MonitorPressure;
				action monitorVolume : MonitorVolume;
				action checkIntegrity : MaintenanceCheck;
			}
			accept removalCmd : RemovalCommand;
			then deflating;
			accept safetyAlert : SafetyAlert;
			then emergency;
		}
		
		state emergency {
			doc /* Emergency deflation initiated due to safety concern. */
			do action emergencyDeflation : DeflateBalloon;
			then deflating;
		}
		
		state deflating {
			doc /* Balloon is being emptied of saline solution. */
			do action deflate : DeflateBalloon;
			then removing;
		}
		
		state removing {
			doc /* Deflated balloon is being extracted via endoscopy. */
			then removed;
		}
		
		state removed {
			doc /* Balloon has been successfully removed from patient. */
		}
	}
	
	part gastricBalloonSystem {
		doc /* 
		The Gastric Balloon System is a minimally invasive medical device designed to assist 
		in weight loss by temporarily reducing gastric capacity. The system's primary function 
		is to occupy space within the stomach, promoting early satiety and reduced food intake.
		
		The balloon is deployed endoscopically in a deflated state, then inflated with sterile 
		saline solution to a volume of 400-700 mL. Once deployed, it remains in the stomach for 
		a treatment period of approximately 6 months, during which it continuously reduces the 
		available volume for food, helping patients achieve 10-15% total body weight loss.
		
		The system incorporates comprehensive monitoring to ensure patient safety, tracking 
		internal pressure, volume, and material integrity throughout the treatment period. 
		At the end of treatment, the balloon is deflated and removed via the same endoscopic 
		approach used for deployment.
		*/
		
		attribute systemID : String;
		attribute treatmentDuration : ISQ::TimeValue = 6.0 [SI::month];
		attribute targetWeightLoss : Real = 12.5;
		
		satisfy safetyReq : SafetyRequirement;
		satisfy functionalReq : FunctionalRequirement;
		satisfy performanceReq : PerformanceRequirement;
		
		part balloon : IntragastricBalloon {
			attribute :>> nominalVolume = 550.0 [SI::mL];
			attribute :>> maxPressure = 60.0 [SI::kPa];
			attribute :>> currentVolume = 0.0 [SI::mL];
			attribute :>> currentPressure = 0.0 [SI::kPa];
			attribute :>> materialIntegrity = 100.0;
			attribute :>> isDeployed = false;
			
			perform action lifecycle : BalloonLifecycle;
		}
		
		part catheter : CatheterSystem {
			attribute :>> catheterDiameter = 5.0 [SI::mm];
			attribute :>> catheterLength = 1200.0 [SI::mm];
		}
		
		part inflationPump : InflationPump {
			attribute :>> maxFlowRate = 100.0;
			attribute :>> salineReservoirCapacity = 1000.0 [SI::mL];
			attribute :>> currentReservoirLevel = 1000.0 [SI::mL];
		}
		
		part deflationPump : DeflationPump {
			attribute :>> maxExtractionRate = 150.0;
			attribute :>> wasteCapacity = 800.0 [SI::mL];
		}
		
		part monitor : MonitoringUnit {
			attribute :>> pressureAlarmThreshold = 55.0 [SI::kPa];
			attribute :>> volumeAlarmThreshold = 650.0 [SI::mL];
			attribute :>> temperatureAlarmThreshold = 39.0 [SI::'°C'];
			attribute :>> monitoringInterval = 1.0 [SI::h];
		}
		
		part controller : ControlUnit {
			attribute :>> treatmentDuration = 6.0 [SI::month];
		}
		
		connection inflationPath connect inflationPump.fluidOutPort to catheter.proximalPort;
		connection catheterToBalloon connect catheter.distalPort to balloon.inflationPort;
		connection deflationPath connect balloon.deflationPort to deflationPump.fluidInPort;
		connection sensorConnection connect balloon.sensorPort to monitor.sensorInputPort;
		connection inflationControl connect controller.inflationControlPort to inflationPump.controlPort;
		connection deflationControl connect controller.deflationControlPort to deflationPump.controlPort;
		
		action operateSystem {
			doc /* 
			Primary operational sequence for gastric balloon weight loss treatment.
			Encompasses deployment, maintenance monitoring, and removal phases.
			*/
			
			first start;
			
			then action deployment : DeployBalloon {
				in targetVolume = balloon.nominalVolume;
				in maxPressure = balloon.maxPressure;
				in inflationRate = inflationPump.maxFlowRate;
				out deploymentSuccess;
			}
			
			then action treatmentPhase {
				doc /* 
				Maintain balloon deployment for prescribed treatment duration 
				with continuous safety monitoring.
				*/
				
				loop {
					action periodicCheck : MaintenanceCheck;
					then action monitorSafety {
						action pressureCheck : MonitorPressure {
							in currentPressure = balloon.currentPressure;
							in maxPressure = balloon.maxPressure;
							out pressureStatus;
							out alert;
						}
						
						action volumeCheck : MonitorVolume {
							in currentVolume = balloon.currentVolume;
							in minVolume = 400.0 [SI::mL];
							in maxVolume = 700.0 [SI::mL];
							out volumeStatus;
							out alert;
						}
					}
					
					then decide;
						if monitorSafety.pressureCheck.pressureStatus == true 
							and monitorSafety.volumeCheck.volumeStatus == true 
							then periodicCheck;
						if monitorSafety.pressureCheck.pressureStatus == false 
							or monitorSafety.volumeCheck.volumeStatus == false 
							then done;
				}
			}
			
			then action removal : RemoveBalloon {
				in currentVolume = balloon.currentVolume;
				in deflationRate = deflationPump.maxExtractionRate;
				out removalSuccess;
			}
			
			then done;
		}
	}
}
