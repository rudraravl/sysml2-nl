package VenousAccessSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientID :> String;
	attribute def DeviceID :> String;
	
	item def Blood {
		attribute volume : VolumeValue;
		attribute viscosity : DynamicViscosityValue;
		attribute oxygenSaturation : Real;
	}
	
	item def InfusionFluid {
		attribute volume : VolumeValue;
		attribute flowRate : VolumeFlowRateValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute composition : String;
	}
	
	item def Medication {
		attribute dosage : MassValue;
		attribute concentration : Real;
		attribute name : String;
	}
	
	item def BloodSample {
		attribute volume : VolumeValue;
		attribute collectionTime : TimeValue;
		attribute testType : String;
	}
	
	attribute def VenousStatus {
		attribute pressure : PressureValue;
		attribute diameter : LengthValue;
		attribute patency : Boolean;
		attribute wallIntegrity : Real;
	}
	
	attribute def CatheterState {
		attribute inserted : Boolean;
		attribute depth : LengthValue;
		attribute flowRate : VolumeFlowRateValue;
		attribute occluded : Boolean;
	}
	
	port def VascularPort {
		attribute venousStatus : VenousStatus;
		in item infusate : InfusionFluid[*];
		in item medication : Medication[*];
		out item bloodSample : BloodSample[*];
	}
	
	port def FluidPort {
		in item fluid : InfusionFluid[*];
		out attribute pressure : PressureValue;
		out attribute flowRate : VolumeFlowRateValue;
	}
	
	port def ControlPort {
		in attribute targetFlowRate : VolumeFlowRateValue;
		in attribute maxPressure : PressureValue;
		out attribute actualFlowRate : VolumeFlowRateValue;
		out attribute systemPressure : PressureValue;
		out attribute alarmStatus : Boolean;
	}
	
	port def MonitoringPort {
		out attribute pressure : PressureValue;
		out attribute flowRate : VolumeFlowRateValue;
		out attribute temperature : ThermodynamicTemperatureValue;
	}
	
	part def PeripheralVein {
		attribute diameter : LengthValue;
		attribute wallThickness : LengthValue;
		attribute baselinePressure : PressureValue;
		attribute elasticity : Real;
		
		port accessPoint : VascularPort;
		
		attribute venousStatus : VenousStatus {
			:>> pressure = baselinePressure;
			:>> diameter = diameter;
			:>> patency = true;
			:>> wallIntegrity = 1.0;
		}
	}
	
	part def VenousCatheter {
		attribute gauge : Integer;
		attribute length : LengthValue;
		attribute insertionDepth : LengthValue;
		attribute maxFlowRate : VolumeFlowRateValue;
		attribute material : String;
		
		port proximalEnd : FluidPort;
		port distalEnd : VascularPort;
		
		attribute state : CatheterState;
	}
	
	part def Hub {
		attribute numberOfPorts : Integer;
		attribute needlelessConnector : Boolean;
		
		port inlet : FluidPort;
		port outlet : FluidPort;
		port sidePort : FluidPort[*];
	}
	
	part def SafetyNeedle {
		attribute needleGauge : Integer;
		attribute needleLength : LengthValue;
		attribute safetyMechanismEngaged : Boolean;
		
		action def Retract {
			first start;
			then assign safetyMechanismEngaged := true;
			then done;
		}
	}
	
	part def PressureSensor {
		attribute sampleRate : FrequencyValue;
		attribute accuracy : PressureValue;
		
		port sensing : FluidPort;
		port output : MonitoringPort;
		
		perform action monitorPressure;
	}
	
	part def FlowRegulator {
		attribute setPoint : VolumeFlowRateValue;
		attribute tolerance : Real;
		
		port control : ControlPort;
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
		
		perform action regulateFlow;
	}
	
	part def InfusionPump {
		attribute pumpRate : VolumeFlowRateValue;
		attribute totalVolumeDelivered : VolumeValue;
		attribute batteryLevel : Real;
		
		port inlet : FluidPort;
		port outlet : FluidPort;
		port control : ControlPort;
		
		perform action deliverFluid;
	}
	
	part def Patient {
		attribute patientID : PatientID;
		attribute weight : MassValue;
		attribute age : Real;
		
		part cardiovascularSystem {
			part antecubitalVein : PeripheralVein {
				attribute :>> diameter = 4.0 [mm];
				attribute :>> wallThickness = 0.5 [mm];
				attribute :>> baselinePressure = 1.33 [kPa];
				attribute :>> elasticity = 0.8;
			}
			
			part cephalicVein : PeripheralVein {
				attribute :>> diameter = 3.5 [mm];
				attribute :>> wallThickness = 0.4 [mm];
				attribute :>> baselinePressure = 1.2 [kPa];
				attribute :>> elasticity = 0.75;
			}
		}
	}
	
	action def LocateVein {
		in patient : Patient;
		out targetVein : PeripheralVein;
		out locationConfirmed : Boolean;
		
		first start;
		then action palpate {
			in vein = patient.cardiovascularSystem.antecubitalVein;
			out suitable : Boolean;
		}
		then decide;
			if palpate.suitable then selectVein;
			if not palpate.suitable then tryAlternate;
		
		action selectVein {
			then assign targetVein := patient.cardiovascularSystem.antecubitalVein;
			then assign locationConfirmed := true;
		}
		then done;
		
		action tryAlternate {
			then assign targetVein := patient.cardiovascularSystem.cephalicVein;
			then assign locationConfirmed := true;
		}
		then done;
	}
	
	action def InsertCatheter {
		in patient : Patient;
		in catheter : VenousCatheter;
		in needle : SafetyNeedle;
		out insertionSuccess : Boolean;
		
		first start;
		then action locate : LocateVein {
			in patient = patient;
			out targetVein;
			out locationConfirmed;
		}
		then decide;
			if locate.locationConfirmed then performVenipuncture;
			if not locate.locationConfirmed then failedInsertion;
		
		action performVenipuncture {
			first action puncture {
				in vein = locate.targetVein;
				out bloodReturn : Boolean;
			}
			then decide;
				if puncture.bloodReturn then advanceCatheter;
				if not puncture.bloodReturn then repositionNeedle;
			
			action advanceCatheter {
				in catheter = catheter;
				out advanced : Boolean;
			}
			then action withdrawNeedle {
				in needle = needle;
			}
			then action retractSafety : SafetyNeedle::Retract;
			then action verifyPlacement {
				out placementConfirmed : Boolean;
			}
			then assign insertionSuccess := verifyPlacement.placementConfirmed;
			then assign catheter.state.inserted := true;
			then done;
			
			action repositionNeedle {
				then assign insertionSuccess := false;
			}
			then done;
		}
		
		action failedInsertion {
			then assign insertionSuccess := false;
		}
		then done;
	}
	
	action def DrawBloodSample {
		in catheter : VenousCatheter;
		in targetVolume : VolumeValue;
		out sample : BloodSample;
		
		first start;
		then action discard {
			attribute discardVolume : VolumeValue = 5.0 [mL];
		}
		then action collectSample {
			in volume = targetVolume;
			out collectedSample : BloodSample {
				:>> volume = volume;
			}
		}
		then action flushCatheter {
			attribute salineVolume : VolumeValue = 10.0 [mL];
		}
		then assign sample := collectSample.collectedSample;
		then done;
	}
	
	action def AdministerInfusion {
		in catheter : VenousCatheter;
		in fluid : InfusionFluid;
		in pump : InfusionPump;
		in targetRate : VolumeFlowRateValue;
		in maxPressure : PressureValue;
		
		first start;
		then merge infusionLoop;
		
		then action setPumpRate {
			in rate = targetRate;
			then assign pump.pumpRate := rate;
		}
		
		then action monitorSystem {
			out currentPressure : PressureValue;
			out currentFlow : VolumeFlowRateValue;
			out remainingVolume : VolumeValue;
		}
		
		then decide;
			if monitorSystem.currentPressure < maxPressure and monitorSystem.remainingVolume > 0.0 [mL] then continueInfusion;
			if monitorSystem.currentPressure >= maxPressure then handleOcclusion;
			if monitorSystem.remainingVolume <= 0.0 [mL] then completeInfusion;
		
		action continueInfusion {
			action deliverFluid {
				in flowRate = targetRate;
			}
		}
		then infusionLoop;
		
		action handleOcclusion {
			action stopPump;
			then action raiseAlarm {
				attribute alarmCode : Integer = 101;
				attribute message : String = "High pressure detected - possible occlusion";
			}
		}
		then done;
		
		action completeInfusion {
			action stopPump;
			then action flushLine {
				attribute salineVolume : VolumeValue = 10.0 [mL];
			}
		}
		then done;
	}
	
	action def MaintainPatency {
		in catheter : VenousCatheter;
		in flushInterval : TimeValue;
		
		first start;
		then merge maintenanceLoop;
		
		then action waitInterval {
			in duration = flushInterval;
		}
		
		then action flushCatheter {
			attribute salineVolume : VolumeValue = 10.0 [mL];
			attribute flushRate : VolumeFlowRateValue = 2.0 [mL/min];
		}
		
		then action assessPatency {
			out patent : Boolean;
		}
		
		then decide;
			if assessPatency.patent then maintenanceLoop;
			if not assessPatency.patent then troubleshoot;
		
		action troubleshoot {
			action checkConnections;
			then action attemptClearance;
		}
		then done;
	}
	
	state def VenousAccessLifecycle {
		entry; then packaged;
		
		state packaged {
			doc /* Device is sterile and sealed in packaging */
		}
		
		transition unpack
			first packaged
			accept UnpackageEvent
			then readyForUse;
		
		state readyForUse {
			doc /* Device is prepared for insertion */
		}
		
		transition insert
			first readyForUse
			accept InsertionEvent
			then deployed;
		
		state deployed {
			entry; then inSitu;
			
			state inSitu {
				doc /* Catheter is in place but not actively in use */
			}
			
			transition startInfusion
				first inSitu
				accept StartInfusionCommand
				then infusing;
			
			transition startDraw
				first inSitu
				accept DrawBloodCommand
				then drawingSample;
			
			state infusing {
				entry action beginInfusion;
				do action continueInfusion;
				exit action stopInfusion;
			}
			
			transition infusionComplete
				first infusing
				accept InfusionCompleteEvent
				then inSitu;
			
			transition pressureAlarm
				first infusing
				accept HighPressureEvent
				then alarm;
			
			state drawingSample {
				entry action startDraw;
				do action continueDraw;
				exit action completeDraw;
			}
			
			transition drawComplete
				first drawingSample
				accept DrawCompleteEvent
				then inSitu;
			
			state alarm {
				entry action activateAlarm;
				
				state highPressure {
					doc /* Pressure exceeds safe threshold */
				}
				
				state occlusion {
					doc /* Catheter is blocked */
				}
				
				state infiltration {
					doc /* Fluid leaking into surrounding tissue */
				}
			}
			
			transition clearAlarm
				first alarm
				accept ResetCommand
				then inSitu;
		}
		
		transition remove
			first deployed
			accept RemovalEvent
			then removed;
		
		state removed {
			doc /* Catheter has been withdrawn from patient */
		}
		
		transition dispose
			first removed
			accept DisposeEvent
			then disposed;
		
		state disposed;
	}
	
	requirement def VenousAccessRequirement {
		doc /* 
		 * The venous access system shall provide safe, reliable, and controlled access 
		 * to the patient's venous circulation for therapeutic and diagnostic purposes.
		 */
		
		subject system : VenousAccessDevice;
	}
	
	requirement <'VA-REQ-001'> safeVenousAccess :> VenousAccessRequirement {
		doc /* 
		 * The system shall establish and maintain venous access while minimizing 
		 * risk of infection, thrombosis, and vascular injury.
		 */
		
		require flowControl;
		require pressureMonitoring;
		require biocompatibility;
	}
	
	requirement <'VA-REQ-002'> flowControl {
		doc /* 
		 * The system shall control infusion flow rates between 1 mL/min and 300 mL/min 
		 * with accuracy of ±5%.
		 */
		
		assume constraint {
			venousAccessDevice.catheter.maxFlowRate >= 300.0 [mL/min]
		}
		
		require constraint {
			venousAccessDevice.flowRegulator.setPoint >= 1.0 [mL/min] and
			venousAccessDevice.flowRegulator.setPoint <= 300.0 [mL/min] and
			venousAccessDevice.flowRegulator.tolerance <= 0.05
		}
	}
	
	requirement <'VA-REQ-003'> pressureMonitoring {
		doc /* 
		 * The system shall continuously monitor line pressure and activate an alarm 
		 * if pressure exceeds 40 kPa to prevent vessel damage.
		 */
		
		require constraint {
			venousAccessDevice.pressureSensor.output.pressure < 40.0 [kPa]
		}
	}
	
	requirement <'VA-REQ-004'> biocompatibility {
		doc /* 
		 * All materials in contact with blood or infusate shall be biocompatible 
		 * per ISO 10993 standards.
		 */
	}
	
	requirement <'VA-REQ-005'> sterileMaintenance {
		doc /* 
		 * The system shall maintain sterility of the fluid path throughout 
		 * the duration of use.
		 */
	}
	
	requirement <'VA-REQ-006'> patencyMaintenance {
		doc /* 
		 * The system shall maintain catheter patency through periodic flushing 
		 * at intervals not exceeding 8 hours.
		 */
		
		require constraint {
			venousAccessDevice.flushInterval <= 8.0 [h]
		}
	}
	
	part def VenousAccessDevice {
		doc /* 
		 * Complete venous access device assembly providing controlled access 
		 * to patient venous circulation for infusion therapy and blood sampling.
		 */
		
		part catheter : VenousCatheter {
			attribute :>> gauge = 20;
			attribute :>> length = 32.0 [mm];
			attribute :>> insertionDepth = 25.0 [mm];
			attribute :>> maxFlowRate = 300.0 [mL/min];
			attribute :>> material = "Polyurethane";
		}
		
		part hub : Hub {
			attribute :>> numberOfPorts = 3;
			attribute :>> needlelessConnector = true;
		}
		
		part needle : SafetyNeedle {
			attribute :>> needleGauge = 20;
			attribute :>> needleLength = 32.0 [mm];
			attribute :>> safetyMechanismEngaged = false;
		}
		
		part flowRegulator : FlowRegulator {
			attribute :>> setPoint = 100.0 [mL/min];
			attribute :>> tolerance = 0.05;
		}
		
		part pressureSensor : PressureSensor {
			attribute :>> sampleRate = 10.0 [Hz];
			attribute :>> accuracy = 0.27 [kPa];
		}
		
		part infusionPump : InfusionPump {
			attribute :>> pumpRate = 100.0 [mL/min];
			attribute :>> totalVolumeDelivered = 0.0 [mL];
			attribute :>> batteryLevel = 1.0;
		}
		
		attribute flushInterval : TimeValue = 8.0 [h];
		
		connect hub.outlet to catheter.proximalEnd;
		connect catheter.proximalEnd to pressureSensor.sensing;
		connect flowRegulator.fluidOut to hub.inlet;
		connect infusionPump.outlet to flowRegulator.fluidIn;
		
		state lifecycle : VenousAccessLifecycle;
		
		satisfy safeVenousAccess by this;
	}
	
	part venousAccessSystem {
		doc /* 
		 * Complete venous access system including device, patient interface, 
		 * and operational procedures for safe therapeutic access to venous circulation.
		 */
		
		part patient : Patient {
			attribute :>> patientID = "PT-12345";
			attribute :>> weight = 70.0 [kg];
			attribute :>> age = 45.0;
		}
		
		part device : VenousAccessDevice;
		
		connect device.catheter.distalEnd to patient.cardiovascularSystem.antecubitalVein.accessPoint;
		
		perform action primaryOperation {
			first start;
			
			then action insertion : InsertCatheter {
				in patient = patient;
				in catheter = device.catheter;
				in needle = device.needle;
				out insertionSuccess;
			}
			
			then decide;
				if insertion.insertionSuccess then therapeuticUse;
				if not insertion.insertionSuccess then abortProcedure;
			
			action therapeuticUse {
				first merge operationCycle;
				
				then decide;
					if infusionRequired then performInfusion;
					if sampleRequired then performDraw;
					if maintenanceRequired then performMaintenance;
				
				action performInfusion : AdministerInfusion {
					in catheter = device.catheter;
					in fluid;
					in pump = device.infusionPump;
					in targetRate = 100.0 [mL/min];
					in maxPressure = 40.0 [kPa];
				}
				then operationCycle;
				
				action performDraw : DrawBloodSample {
					in catheter = device.catheter;
					in targetVolume = 10.0 [mL];
					out sample;
				}
				then operationCycle;
				
				action performMaintenance : MaintainPatency {
					in catheter = device.catheter;
					in flushInterval = device.flushInterval;
				}
				then operationCycle;
			}
			
			action abortProcedure;
			then done;
		}
	}
}
