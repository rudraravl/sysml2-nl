package 'OneTouch Ultra Blood Glucose Monitoring System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def GlucoseConcentration :> Real {
		doc /* Blood glucose concentration in mg/dL */
	}
	
	attribute def StripInsertedSignal;
	attribute def BloodAppliedSignal;
	attribute def MeasurementCompleteSignal;
	attribute def ResultDisplayedSignal;
	
	value def GlucoseReading {
		attribute concentration : GlucoseConcentration;
		attribute timestamp : ISQ::TimeValue;
		attribute isValid : Boolean;
	}
	
	item def TestStrip {
		attribute enzymeActive : Boolean;
		attribute sampleDetected : Boolean;
	}
	
	item def BloodSample {
		attribute volume : ISQ::VolumeValue;
		attribute glucoseContent : GlucoseConcentration;
	}
	
	port def SampleInputPort {
		in item bloodSample : BloodSample;
	}
	
	port def DataOutputPort {
		out reading : GlucoseReading;
	}
	
	port def StripInterfacePort {
		in item strip : TestStrip;
	}
	
	part def ElectrochemicalSensor {
		doc /* Converts glucose concentration to electrical current via enzymatic reaction */
		
		port samplePort : SampleInputPort;
		attribute measuredCurrent : ISQ::ElectricCurrentValue;
		
		action performSensing {
			in sample : BloodSample;
			out current : ISQ::ElectricCurrentValue;
		}
	}
	
	part def AnalogToDigitalConverter {
		doc /* Converts analog sensor current to digital signal */
		
		action convertSignal {
			in analogCurrent : ISQ::ElectricCurrentValue;
			out digitalValue : Real;
		}
	}
	
	part def Microcontroller {
		doc /* Processes sensor data and calculates glucose concentration */
		
		attribute calibrationCurve : Real[*];
		
		action calculateGlucose {
			in digitalSignal : Real;
			in calibration : Real;
			out concentration : GlucoseConcentration;
		}
		
		action validateMeasurement {
			in concentration : GlucoseConcentration;
			out valid : Boolean;
		}
	}
	
	part def LiquidCrystalDisplay {
		doc /* Displays glucose reading to user */
		
		port displayPort : DataOutputPort;
		
		action displayReading {
			in reading : GlucoseReading;
		}
		
		action displayError {
			in errorMessage : String;
		}
	}
	
	part def NonvolatileMemory {
		doc /* Stores historical glucose readings */
		
		attribute readings : GlucoseReading[450];
		attribute currentIndex : Integer := 0;
		
		action storeReading {
			in reading : GlucoseReading;
			out success : Boolean;
		}
		
		action retrieveHistory {
			in numberOfReadings : Integer;
			out historicalData : GlucoseReading[*];
		}
	}
	
	part def BatteryPowerSource {
		doc /* Provides electrical power to system components */
		
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute remainingCapacity : Real;
		
		action checkPowerLevel {
			out sufficient : Boolean;
		}
	}
	
	action def PerformGlucoseMeasurement {
		in testStrip : TestStrip;
		in bloodSample : BloodSample;
		out measurementResult : GlucoseReading;
	}
	
	action glucoseMeasurementProcess : PerformGlucoseMeasurement {
		doc /* 
			Complete glucose measurement workflow from strip insertion to result display.
			This represents the primary function of the OneTouch Ultra system.
		*/
		
		first start;
		
		then action insertStrip {
			accept stripInserted : StripInsertedSignal;
			out strip : TestStrip;
		}
		
		then action waitForBlood {
			accept bloodApplied : BloodAppliedSignal;
			out sample : BloodSample;
		}
		
		then action executeMeasurement {
			in strip = insertStrip.strip;
			in sample = waitForBlood.sample;
			
			action applyVoltageToStrip {
				out appliedVoltage : ISQ::ElectricPotentialValue;
			}
			
			then action measureElectricalCurrent {
				in voltage = applyVoltageToStrip.appliedVoltage;
				out current : ISQ::ElectricCurrentValue;
			}
			
			then action convertToDigital {
				in analogCurrent = measureElectricalCurrent.current;
				out digitalSignal : Real;
			}
			
			then action computeGlucoseConcentration {
				in signal = convertToDigital.digitalSignal;
				out glucoseValue : GlucoseConcentration;
			}
			
			then action validateResult {
				in concentration = computeGlucoseConcentration.glucoseValue;
				out isValid : Boolean;
				out finalReading : GlucoseReading {
					attribute :>> concentration = concentration;
					attribute :>> isValid = (concentration >= 20.0) and (concentration <= 600.0);
				}
			}
			
			out result = validateResult.finalReading;
		}
		
		then decide;
			if executeMeasurement.result.isValid then presentResult;
			if not executeMeasurement.result.isValid then handleError;
		
		action presentResult {
			in reading = executeMeasurement.result;
			
			action updateDisplay {
				in resultToShow = reading;
				send displayed : ResultDisplayedSignal;
			}
			
			then action archiveReading {
				in resultToStore = reading;
			}
			
			then action notifyComplete {
				send complete : MeasurementCompleteSignal;
			}
		}
		then finish;
		
		action handleError {
			action displayErrorCode {
				in errorType : String := "Measurement out of range";
			}
		}
		then finish;
		
		action finish;
		then done;
	}
	
	state def MeterStateMachine {
		doc /* Operational states of the OneTouch Ultra meter */
		
		entry; then PowerOff;
		
		state PowerOff;
		accept StripInsertedSignal;
		then StandbyMode;
		
		state StandbyMode {
			doc /* Meter is on and waiting for blood sample */
			entry action activateDisplay;
		}
		accept BloodAppliedSignal;
		then Measuring;
		
		state Measuring {
			doc /* Actively measuring glucose concentration */
			entry action startMeasurement;
			do action processSample;
		}
		accept MeasurementCompleteSignal;
		then DisplayingResult;
		
		state DisplayingResult {
			doc /* Showing glucose reading to user */
			entry action showResult;
			do action saveToMemory;
		}
		then StandbyMode;
		
		action activateDisplay;
		action startMeasurement;
		action processSample;
		action showResult;
		action saveToMemory;
	}
	
	part def OneTouchUltraMeter {
		doc /* 
			OneTouch Ultra blood glucose monitoring system.
			Primary function: Accurately measure and display blood glucose concentration
			from a small blood sample applied to a disposable test strip.
		*/
		
		port stripSlot : StripInterfacePort;
		port userInterface : DataOutputPort;
		
		part sensor : ElectrochemicalSensor {
			port :>> samplePort;
		}
		
		part adc : AnalogToDigitalConverter;
		
		part controller : Microcontroller;
		
		part display : LiquidCrystalDisplay {
			port :>> displayPort;
		}
		
		part memory : NonvolatileMemory;
		
		part battery : BatteryPowerSource;
		
		connection sensorToADC connect sensor to adc;
		connection adcToController connect adc to controller;
		connection controllerToDisplay connect controller to display.displayPort;
		connection controllerToMemory connect controller to memory;
		connection stripToSensor connect stripSlot to sensor.samplePort;
		connection displayToUser connect display.displayPort to userInterface;
		
		exhibit state meterBehavior : MeterStateMachine;
		perform action measureGlucose[*] ordered references glucoseMeasurementProcess;
	}
	
	requirement <'REQ-FUNC-001'> primaryFunctionRequirement {
		doc /* 
			The OneTouch Ultra system shall measure blood glucose concentration from a capillary 
			blood sample and display the result to the user within 5 seconds of sample application.
		*/
		
		subject meter : OneTouchUltraMeter;
	}
	
	requirement <'REQ-ACC-001'> measurementAccuracyRequirement {
		doc /* 
			The system shall measure blood glucose concentration with accuracy of ±15% for 
			concentrations >= 75 mg/dL and ±15 mg/dL for concentrations < 75 mg/dL, 
			as verified against laboratory reference methods.
		*/
		
		subject meter : OneTouchUltraMeter;
		
		require constraint {
			meter.sensor.measuredCurrent >= 0.0[SI::A]
		}
	}
	
	requirement <'REQ-RANGE-001'> measurementRangeRequirement {
		doc /* 
			The system shall accurately measure blood glucose concentrations 
			in the range of 20 to 600 mg/dL.
		*/
		
		require constraint {
			glucoseMeasurementProcess.executeMeasurement.computeGlucoseConcentration.glucoseValue >= 20.0 and
			glucoseMeasurementProcess.executeMeasurement.computeGlucoseConcentration.glucoseValue <= 600.0
		}
	}
	
	requirement <'REQ-SAMPLE-001'> sampleVolumeRequirement {
		doc /* 
			The system shall perform accurate measurements with a minimum 
			blood sample volume of 1 microliter.
		*/
		
		require constraint {
			glucoseMeasurementProcess.waitForBlood.sample.volume >= 1.0e-9[SI::m ** 3]
		}
	}
	
	requirement <'REQ-MEM-001'> dataStorageRequirement {
		doc /* 
			The system shall store a minimum of 450 glucose readings 
			with associated timestamps in nonvolatile memory.
		*/
		
		subject memory : NonvolatileMemory;
		
		require constraint {
			memory.readings->size() <= 450
		}
	}
	
	requirement <'REQ-TIME-001'> measurementTimeRequirement {
		doc /* 
			The system shall complete glucose measurement and display result 
			within 5 seconds of blood sample application.
		*/
		
		subject process : PerformGlucoseMeasurement;
	}
	
	requirement systemLevelRequirements {
		doc /* Top-level requirements for OneTouch Ultra blood glucose monitoring system */
		
		require primaryFunctionRequirement;
		require measurementAccuracyRequirement;
		require measurementRangeRequirement;
		require sampleVolumeRequirement;
		require dataStorageRequirement;
		require measurementTimeRequirement;
	}
}
