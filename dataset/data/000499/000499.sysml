package SingleUseMedicalDeviceReprocessingSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def SterilityAssuranceLevel {
		attribute value : Real;
		doc /* Probability of non-sterile unit, typically 10^-6 */
	}
	
	attribute def BioburdenCount {
		attribute cfu : Real;
		doc /* Colony Forming Units per device */
	}
	
	attribute def EndotoxinLevel {
		attribute euPerDevice : Real;
		doc /* Endotoxin Units per device */
	}
	
	attribute def TemperatureCelsius :> TemperatureValue;
	attribute def PressureKPa :> PressureValue;
	attribute def DurationMinutes :> DurationValue;
	attribute def FlowRateLPM :> VolumeFlowRateValue;
	
	item def SingleUseDevice {
		attribute deviceID : String;
		attribute deviceType : String;
		attribute initialBioburden : BioburdenCount;
		attribute currentBioburden : BioburdenCount;
		attribute endotoxinLevel : EndotoxinLevel;
		attribute functionalIntegrity : Boolean;
		attribute reprocessCycleCount : Integer;
		attribute sterile : Boolean;
	}
	
	item def CleaningSolution {
		attribute solutionType : String;
		attribute concentration : Real;
		attribute volume : VolumeValue;
		attribute temperature : TemperatureCelsius;
	}
	
	item def SterilizationAgent {
		attribute agentType : String;
		attribute concentration : Real;
		attribute exposureTime : DurationMinutes;
	}
	
	port def DeviceInputPort {
		in item device : SingleUseDevice;
	}
	
	port def DeviceOutputPort {
		out item device : SingleUseDevice;
	}
	
	port def CleaningSolutionPort {
		in item solution : CleaningSolution;
	}
	
	port def SterilizationAgentPort {
		in item agent : SterilizationAgent;
	}
	
	part def PreInspectionStation {
		port deviceIn : DeviceInputPort;
		port deviceOut : DeviceOutputPort;
		
		attribute visualInspectionPassed : Boolean;
		attribute deviceAccepted : Boolean;
		
		perform action inspectIncomingDevice {
			in device : SingleUseDevice;
			out accepted : Boolean;
			out bioburdenEstimate : BioburdenCount;
		}
	}
	
	part def PreCleaningStation {
		port deviceIn : DeviceInputPort;
		port deviceOut : DeviceOutputPort;
		
		attribute soakDuration : DurationMinutes;
		
		perform action preClean {
			in device : SingleUseDevice;
			in duration : DurationMinutes;
			out preCleanedDevice : SingleUseDevice;
		}
	}
	
	part def AutomatedWashingStation {
		port deviceIn : DeviceInputPort;
		port deviceOut : DeviceOutputPort;
		port cleaningSolutionIn : CleaningSolutionPort;
		
		attribute washTemperature : TemperatureCelsius;
		attribute washDuration : DurationMinutes;
		attribute flowRate : FlowRateLPM;
		attribute cycleCount : Integer;
		
		perform action washDevice {
			in device : SingleUseDevice;
			in solution : CleaningSolution;
			in temperature : TemperatureCelsius;
			in duration : DurationMinutes;
			out washedDevice : SingleUseDevice;
		}
	}
	
	part def UltrasonicCleaningStation {
		port deviceIn : DeviceInputPort;
		port deviceOut : DeviceOutputPort;
		port cleaningSolutionIn : CleaningSolutionPort;
		
		attribute frequency : Real;
		attribute power : Real;
		attribute cleaningDuration : DurationMinutes;
		
		perform action ultrasonicClean {
			in device : SingleUseDevice;
			in solution : CleaningSolution;
			in duration : DurationMinutes;
			out cleanedDevice : SingleUseDevice;
		}
	}
	
	part def RinseStation {
		port deviceIn : DeviceInputPort;
		port deviceOut : DeviceOutputPort;
		
		attribute rinseTemperature : TemperatureCelsius;
		attribute rinseDuration : DurationMinutes;
		attribute waterQuality : String;
		
		perform action rinseDevice {
			in device : SingleUseDevice;
			in temperature : TemperatureCelsius;
			in duration : DurationMinutes;
			out rinsedDevice : SingleUseDevice;
		}
	}
	
	part def DryingStation {
		port deviceIn : DeviceInputPort;
		port deviceOut : DeviceOutputPort;
		
		attribute dryingTemperature : TemperatureCelsius;
		attribute dryingDuration : DurationMinutes;
		attribute airFlowRate : FlowRateLPM;
		
		perform action dryDevice {
			in device : SingleUseDevice;
			in temperature : TemperatureCelsius;
			in duration : DurationMinutes;
			out driedDevice : SingleUseDevice;
		}
	}
	
	part def FunctionalTestingStation {
		port deviceIn : DeviceInputPort;
		port deviceOut : DeviceOutputPort;
		
		attribute testPassed : Boolean;
		attribute functionalityScore : Real;
		
		perform action testFunctionality {
			in device : SingleUseDevice;
			out testResult : Boolean;
			out testedDevice : SingleUseDevice;
		}
	}
	
	part def SterilizationChamber {
		port deviceIn : DeviceInputPort;
		port deviceOut : DeviceOutputPort;
		port sterilizationAgentIn : SterilizationAgentPort;
		
		attribute chamberTemperature : TemperatureCelsius;
		attribute chamberPressure : PressureKPa;
		attribute exposureDuration : DurationMinutes;
		attribute sterilizationMethod : String;
		
		perform action sterilizeDevice {
			in device : SingleUseDevice;
			in agent : SterilizationAgent;
			in temperature : TemperatureCelsius;
			in pressure : PressureKPa;
			in duration : DurationMinutes;
			out sterilizedDevice : SingleUseDevice;
		}
	}
	
	part def SterilityTestingStation {
		port deviceIn : DeviceInputPort;
		port deviceOut : DeviceOutputPort;
		
		attribute salAchieved : SterilityAssuranceLevel;
		attribute sterilityConfirmed : Boolean;
		
		perform action verifySterility {
			in device : SingleUseDevice;
			out sterile : Boolean;
			out sal : SterilityAssuranceLevel;
		}
	}
	
	part def PackagingStation {
		port deviceIn : DeviceInputPort;
		port deviceOut : DeviceOutputPort;
		
		attribute sealIntegrity : Boolean;
		attribute packageType : String;
		attribute labelingComplete : Boolean;
		
		perform action packageDevice {
			in device : SingleUseDevice;
			out packagedDevice : SingleUseDevice;
		}
	}
	
	part def StorageUnit {
		port deviceIn : DeviceInputPort;
		
		attribute storageTemperature : TemperatureCelsius;
		attribute storageHumidity : Real;
		attribute inventoryCount : Integer;
		
		perform action storeDevice {
			in device : SingleUseDevice;
		}
	}
	
	part def RejectStation {
		port deviceIn : DeviceInputPort;
		
		attribute rejectReason : String;
		attribute rejectCount : Integer;
		
		perform action rejectDevice {
			in device : SingleUseDevice;
			in reason : String;
		}
	}
	
	part reprocessingFacility {
		doc /* 
			Automated facility for reprocessing single-use medical devices.
			Primary function: Clean, sterilize, test, and repackage single-use devices
			to meet regulatory standards for safe reuse, reducing medical waste and costs.
		*/
		
		part preInspection : PreInspectionStation;
		part preCleaning : PreCleaningStation;
		part automatedWashing : AutomatedWashingStation;
		part ultrasonicCleaning : UltrasonicCleaningStation;
		part rinsing : RinseStation;
		part drying : DryingStation;
		part functionalTesting : FunctionalTestingStation;
		part sterilization : SterilizationChamber;
		part sterilityTesting : SterilityTestingStation;
		part packaging : PackagingStation;
		part storage : StorageUnit;
		part rejection : RejectStation;
		
		connection connect preInspection.deviceOut to preCleaning.deviceIn;
		connection connect preCleaning.deviceOut to automatedWashing.deviceIn;
		connection connect automatedWashing.deviceOut to ultrasonicCleaning.deviceIn;
		connection connect ultrasonicCleaning.deviceOut to rinsing.deviceIn;
		connection connect rinsing.deviceOut to drying.deviceIn;
		connection connect drying.deviceOut to functionalTesting.deviceIn;
		connection connect functionalTesting.deviceOut to sterilization.deviceIn;
		connection connect sterilization.deviceOut to sterilityTesting.deviceIn;
		connection connect sterilityTesting.deviceOut to packaging.deviceIn;
		connection connect packaging.deviceOut to storage.deviceIn;
		
		perform action reprocessDeviceWorkflow {
			first start;
			
			then action receiveDevice {
				out usedDevice : SingleUseDevice;
			}
			
			then action preInspect : PreInspectionStation::inspectIncomingDevice {
				in device = receiveDevice.usedDevice;
			}
			
			then decide;
				if preInspect.accepted == true then proceedToPreCleaning;
				if preInspect.accepted == false then rejectAtInspection;
			
			action proceedToPreCleaning;
			then action preCleanDevice : PreCleaningStation::preClean {
				in device = receiveDevice.usedDevice;
			}
			
			then action washDevice : AutomatedWashingStation::washDevice {
				in device = preCleanDevice.preCleanedDevice;
			}
			
			then action ultrasonicCleanDevice : UltrasonicCleaningStation::ultrasonicClean {
				in device = washDevice.washedDevice;
			}
			
			then action rinseDevice : RinseStation::rinseDevice {
				in device = ultrasonicCleanDevice.cleanedDevice;
			}
			
			then action dryDevice : DryingStation::dryDevice {
				in device = rinseDevice.rinsedDevice;
			}
			
			then action testDevice : FunctionalTestingStation::testFunctionality {
				in device = dryDevice.driedDevice;
			}
			
			then decide;
				if testDevice.testResult == true then proceedToSterilization;
				if testDevice.testResult == false then rejectAtTesting;
			
			action proceedToSterilization;
			then action sterilizeDevice : SterilizationChamber::sterilizeDevice {
				in device = testDevice.testedDevice;
			}
			
			then action verifySterility : SterilityTestingStation::verifySterility {
				in device = sterilizeDevice.sterilizedDevice;
			}
			
			then decide;
				if verifySterility.sterile == true then proceedToPackaging;
				if verifySterility.sterile == false then rejectAtSterility;
			
			action proceedToPackaging;
			then action packageDevice : PackagingStation::packageDevice {
				in device = verifySterility.device;
			}
			
			then action storeDevice : StorageUnit::storeDevice {
				in device = packageDevice.packagedDevice;
			}
			then releaseForUse;
			
			action releaseForUse;
			then done;
			
			action rejectAtInspection : RejectStation::rejectDevice {
				in device = receiveDevice.usedDevice;
				in reason = "Failed pre-inspection";
			}
			then done;
			
			action rejectAtTesting : RejectStation::rejectDevice {
				in device = testDevice.testedDevice;
				in reason = "Failed functional testing";
			}
			then done;
			
			action rejectAtSterility : RejectStation::rejectDevice {
				in device = verifySterility.device;
				in reason = "Failed sterility verification";
			}
			then done;
		}
	}
	
	state machine def DeviceReprocessingLifecycle {
		entry; then used;
		
		state used;
		accept at used then preInspected;
		
		state preInspected;
		accept at preInspected
			if preInspected.deviceAccepted then cleaned
			else rejected;
		
		state cleaned;
		accept at cleaned then dried;
		
		state dried;
		accept at dried then functionallyTested;
		
		state functionallyTested;
		accept at functionallyTested
			if functionallyTested.functionalIntegrity then sterilized
			else rejected;
		
		state sterilized;
		accept at sterilized then sterilityVerified;
		
		state sterilityVerified;
		accept at sterilityVerified
			if sterilityVerified.sterile then packaged
			else rejected;
		
		state packaged;
		accept at packaged then readyForReuse;
		
		state readyForReuse;
		state rejected;
	}
	
	requirement def SterilityAssuranceRequirement {
		doc /* 
			Reprocessed devices must achieve a Sterility Assurance Level (SAL) 
			of 10^-6 or better per FDA and ISO 14937 standards.
		*/
		
		subject device : SingleUseDevice;
		
		require constraint {
			device.sterile == true
		}
	}
	
	requirement def BioburdenReductionRequirement {
		doc /* 
			Cleaning process must reduce bioburden by at least 99.99% 
			(4-log reduction) from initial contamination level.
		*/
		
		subject device : SingleUseDevice;
		
		require constraint {
			device.currentBioburden.cfu <= device.initialBioburden.cfu * 0.0001
		}
	}
	
	requirement def FunctionalIntegrityRequirement {
		doc /* 
			Reprocessed device must maintain functional integrity equivalent 
			to original device specifications.
		*/
		
		subject device : SingleUseDevice;
		
		require constraint {
			device.functionalIntegrity == true
		}
	}
	
	requirement def EndotoxinLimitRequirement {
		doc /* 
			Endotoxin level must not exceed 0.5 EU per device per FDA guidance.
		*/
		
		subject device : SingleUseDevice;
		
		require constraint {
			device.endotoxinLevel.euPerDevice <= 0.5
		}
	}
	
	requirement def TraceabilityRequirement {
		doc /* 
			Each reprocessed device must maintain complete traceability 
			including device ID, reprocess cycle count, and processing history.
		*/
		
		subject device : SingleUseDevice;
		
		require constraint {
			device.deviceID != null and 
			device.reprocessCycleCount >= 0
		}
	}
	
	requirement def ProcessValidationRequirement {
		doc /* 
			Reprocessing workflow must be validated per ISO 17665 and 
			ISO 14937 for consistent, reproducible results.
		*/
		
		subject facility : reprocessingFacility;
		
		require constraint {
			facility.sterilization.chamberTemperature >= 121.0
		}
	}
	
	requirement systemRequirements {
		doc /* 
			Top-level requirements for single-use medical device reprocessing system 
			ensuring safety, efficacy, and regulatory compliance.
		*/
		
		requirement sterilityReq : SterilityAssuranceRequirement;
		requirement bioburdenReq : BioburdenReductionRequirement;
		requirement functionalReq : FunctionalIntegrityRequirement;
		requirement endotoxinReq : EndotoxinLimitRequirement;
		requirement traceabilityReq : TraceabilityRequirement;
		requirement validationReq : ProcessValidationRequirement;
	}
}
