package 'Peak Expiratory Flow System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FlowRate :> ISQ::VolumeFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::VolumeFlowRateUnit;
	}
	
	attribute def PressureValue :> ISQ::PressureValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::PressureUnit;
	}
	
	attribute def TimeValue :> ISQ::TimeValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::TimeUnit;
	}
	
	item def AirStream {
		attribute flowRate : FlowRate;
		attribute pressure : PressureValue;
		attribute timestamp : TimeValue;
	}
	
	item def PeakFlowReading {
		attribute peakValue : FlowRate;
		attribute measurementTime : TimeValue;
		attribute isValid : Boolean;
	}
	
	port def AirInletPort {
		in item airflow : AirStream;
		attribute inletPressure : PressureValue;
	}
	
	port def AirOutletPort {
		out item airflow : AirStream;
	}
	
	port def SensorDataPort {
		out item flowData : AirStream;
	}
	
	port def ProcessorInputPort {
		in item flowData : AirStream;
	}
	
	port def ProcessorOutputPort {
		out item reading : PeakFlowReading;
	}
	
	port def DisplayInputPort {
		in item reading : PeakFlowReading;
	}
	
	part def Mouthpiece {
		port airIntake : AirInletPort;
		port airPassthrough : AirOutletPort;
		attribute diameter : ISQ::LengthValue;
	}
	
	part def FlowSensor {
		port airInput : AirInletPort;
		port dataOutput : SensorDataPort;
		attribute sensitivity : Real;
		attribute calibrationFactor : Real;
	}
	
	part def SignalProcessor {
		port dataInput : ProcessorInputPort;
		port resultOutput : ProcessorOutputPort;
		attribute peakDetected : FlowRate;
		attribute samplingRate : Real;
	}
	
	part def DisplayUnit {
		port dataInput : DisplayInputPort;
		attribute currentDisplay : FlowRate;
		attribute displayMode : String;
	}
	
	action def SenseAirflow {
		in airstream : AirStream;
		out flowData : AirStream;
	}
	
	action def DetectPeakFlow {
		in flowData : AirStream[1..*];
		out peakFlow : FlowRate;
		out detectionTime : TimeValue;
	}
	
	action def ValidateReading {
		in peakFlow : FlowRate;
		in duration : TimeValue;
		out isValid : Boolean;
	}
	
	action def DisplayReading {
		in reading : PeakFlowReading;
		out displayComplete : Boolean;
	}
	
	action def ResetMeter {
		out ready : Boolean;
	}
	
	state def MeterOperationState {
		entry action initialize;
		
		state Idle {
			entry action prepareForMeasurement;
		}
		
		state Ready {
			entry action awaitPatient;
		}
		
		state Measuring {
			entry action captureFlow;
			do action continuousMonitoring;
		}
		
		state Analyzing {
			entry action processPeak;
		}
		
		state Displaying {
			entry action showResult;
		}
		
		state Complete;
		
		transition idle_to_ready
			first Idle
			accept startSignal
			then Ready;
		
		transition ready_to_measuring
			first Ready
			accept breathDetected
			then Measuring;
		
		transition measuring_to_analyzing
			first Measuring
			accept exhalationComplete
			then Analyzing;
		
		transition analyzing_to_displaying
			first Analyzing
			accept peakCalculated
			then Displaying;
		
		transition displaying_to_complete
			first Displaying
			accept resultShown
			then Complete;
		
		transition complete_to_idle
			first Complete
			accept resetRequested
			then Idle;
	}
	
	action def MeasurePeakExpiratoryFlow {
		in patientExhalation : AirStream;
		out measurement : PeakFlowReading;
		
		first start;
		
		then action reset : ResetMeter {
			out ready : Boolean;
		}
		
		then action sense : SenseAirflow {
			in airstream = patientExhalation;
			out flowData : AirStream;
		}
		
		flow sense.flowData to detect.flowData;
		
		then action detect : DetectPeakFlow {
			in flowData : AirStream[1..*];
			out peakFlow : FlowRate;
			out detectionTime : TimeValue;
		}
		
		flow detect.peakFlow to validate.peakFlow;
		flow detect.detectionTime to validate.duration;
		
		then action validate : ValidateReading {
			in peakFlow : FlowRate;
			in duration : TimeValue;
			out isValid : Boolean;
		}
		
		then decide;
			if validate.isValid then displayResult;
			if !validate.isValid then retryMeasurement;
		
		action displayResult : DisplayReading {
			in reading : PeakFlowReading;
			out displayComplete : Boolean;
		}
		then measurementDone;
		
		action retryMeasurement : ResetMeter {
			out ready : Boolean;
		}
		then sense;
		
		action measurementDone;
		then done;
	}
	
	part def PeakFlowMeter {
		attribute deviceID : String;
		attribute calibrationDate : TimeValue;
		attribute measurementRange : FlowRate[2];
		
		part mouthpiece : Mouthpiece {
			port :>> airIntake;
			port :>> airPassthrough;
		}
		
		part sensor : FlowSensor {
			port :>> airInput;
			port :>> dataOutput;
		}
		
		part processor : SignalProcessor {
			port :>> dataInput;
			port :>> resultOutput;
		}
		
		part display : DisplayUnit {
			port :>> dataInput;
		}
		
		connect mouthpiece.airPassthrough to sensor.airInput;
		connect sensor.dataOutput to processor.dataInput;
		connect processor.resultOutput to display.dataInput;
		
		perform action measureFlow : MeasurePeakExpiratoryFlow;
		exhibit state machine operation : MeterOperationState;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The peak expiratory flow meter shall measure and display 
		       the maximum flow rate achieved during a forced exhalation 
		       maneuver by a patient. */
		
		subject meter : PeakFlowMeter;
		
		require constraint {
			meter.measurementRange[1].num >= 50.0 and
			meter.measurementRange[2].num <= 850.0
		}
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The device shall measure peak expiratory flow with accuracy 
		       of ±10% or ±10 L/min, whichever is greater, across the 
		       measurement range. */
		
		subject sensor : FlowSensor;
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The system shall detect and display the peak flow value 
		       within 1.5 seconds of exhalation completion. */
		
		subject processor : SignalProcessor;
	}
	
	requirement def UsabilityRequirement {
		doc /* The device shall provide clear visual feedback to guide 
		       the patient through the measurement process. */
		
		subject display : DisplayUnit;
	}
	
	part def Patient {
		port mouth : AirOutletPort;
	}
	
	part peakFlowMonitoringSystem : PeakFlowMeter {
		attribute :>> deviceID = "PFM-2024-001";
		
		satisfy PrimaryFunctionRequirement by peakFlowMonitoringSystem;
		satisfy MeasurementAccuracyRequirement by peakFlowMonitoringSystem.sensor;
		satisfy ResponseTimeRequirement by peakFlowMonitoringSystem.processor;
		satisfy UsabilityRequirement by peakFlowMonitoringSystem.display;
	}
	
	occurrence def PeakFlowMeasurementSession {
		ref part patient : Patient;
		ref part device : PeakFlowMeter;
		
		message exhalationStart
			from patient.mouth to device.mouthpiece.airIntake;
		
		then message sensorCapture
			from device.mouthpiece to device.sensor;
		
		then message dataTransfer of flowData : AirStream
			from device.sensor.dataOutput to device.processor.dataInput;
		
		then message resultDisplay of reading : PeakFlowReading
			from device.processor.resultOutput to device.display.dataInput;
	}
}
