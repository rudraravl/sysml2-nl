package 'Artificial Heart System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def HeartRate :> ISQ::FrequencyValue {
		doc /* Heart rate measured in beats per minute */
	}
	
	attribute def BloodPressure :> ISQ::PressureValue {
		doc /* Blood pressure measured in mmHg */
	}
	
	attribute def BloodFlowRate :> ISQ::VolumeFlowRateValue {
		doc /* Blood flow rate measured in liters per minute */
	}
	
	attribute def BatteryLevel :> Real {
		doc /* Battery charge level as percentage (0-100) */
	}
	
	attribute def StrokeVolume :> ISQ::VolumeValue {
		doc /* Volume of blood pumped per heartbeat */
	}
	
	item def Blood {
		attribute oxygenSaturation : Real;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute viscosity : Real;
	}
	
	enum def OperationalStatus {
		normal;
		warning;
		critical;
		standby;
	}
	
	enum def ValveState {
		open;
		closed;
	}
	
	port def BloodInletPort {
		in item bloodIn : Blood;
		attribute inletPressure : BloodPressure;
		attribute inletFlow : BloodFlowRate;
	}
	
	port def BloodOutletPort {
		out item bloodOut : Blood;
		attribute outletPressure : BloodPressure;
		attribute outletFlow : BloodFlowRate;
	}
	
	port def PowerPort {
		in attribute powerSupply : ISQ::PowerValue;
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def ControlSignalPort {
		in attribute targetRate : HeartRate;
		in attribute targetPressure : BloodPressure;
		out attribute actualRate : HeartRate;
		out attribute actualPressure : BloodPressure;
		out attribute status : OperationalStatus;
	}
	
	port def SensorPort {
		out attribute measuredPressure : BloodPressure;
		out attribute measuredFlow : BloodFlowRate;
		out attribute measuredTemperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	part def Sensor {
		port sensorOutput : SensorPort;
		
		action def MeasureVitals {
			out pressure : BloodPressure;
			out flowRate : BloodFlowRate;
			out temperature : ISQ::ThermodynamicTemperatureValue;
		}
		
		perform action measure : MeasureVitals;
	}
	
	part def Valve {
		attribute currentState : ValveState;
		attribute responseTime : ISQ::TimeValue;
		
		action def OpenValve {
			out valveState : ValveState;
		}
		
		action def CloseValve {
			out valveState : ValveState;
		}
	}
	
	part def PumpChamber {
		port inlet : BloodInletPort;
		port outlet : BloodOutletPort;
		
		attribute currentVolume : StrokeVolume;
		attribute maxVolume : StrokeVolume;
		attribute minVolume : StrokeVolume;
		
		action def FillChamber {
			in bloodFlow : Blood;
			in fillRate : BloodFlowRate;
			out chamberVolume : StrokeVolume;
		}
		
		action def EjectBlood {
			in chamberVolume : StrokeVolume;
			in ejectionForce : ISQ::ForceValue;
			out bloodFlow : Blood;
			out ejectionPressure : BloodPressure;
			out ejectionFlow : BloodFlowRate;
		}
	}
	
	part def Motor {
		port power : PowerPort;
		
		attribute speed : ISQ::AngularVelocityValue;
		attribute torque : ISQ::TorqueValue;
		attribute efficiency : Real;
		
		action def DriveActuator {
			in commandedSpeed : ISQ::AngularVelocityValue;
			in loadTorque : ISQ::TorqueValue;
			out actualSpeed : ISQ::AngularVelocityValue;
			out outputTorque : ISQ::TorqueValue;
			out powerConsumption : ISQ::PowerValue;
		}
		
		perform action drive : DriveActuator;
	}
	
	part def Controller {
		port controlInterface : ControlSignalPort;
		port sensorInput : SensorPort;
		
		in attribute sensorPressure : BloodPressure;
		in attribute sensorFlow : BloodFlowRate;
		in attribute batteryStatus : BatteryLevel;
		out attribute pumpCommand : HeartRate;
		out attribute systemStatus : OperationalStatus;
		
		action def RegulateHeartRate {
			in targetRate : HeartRate;
			in currentPressure : BloodPressure;
			in currentFlow : BloodFlowRate;
			out adjustedRate : HeartRate;
		}
		
		action def MonitorSystem {
			in batteryLevel : BatteryLevel;
			in pressureReading : BloodPressure;
			in flowReading : BloodFlowRate;
			out systemStatus : OperationalStatus;
		}
	}
	
	part def Battery {
		port powerOutput : PowerPort;
		
		attribute chargeLevel : BatteryLevel;
		attribute capacity : ISQ::EnergyValue;
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		
		action def SupplyPower {
			in powerDemand : ISQ::PowerValue;
			out deliveredPower : ISQ::PowerValue;
			out remainingCharge : BatteryLevel;
		}
		
		action def MonitorCharge {
			out currentCharge : BatteryLevel;
			out estimatedRuntime : ISQ::TimeValue;
		}
		
		perform action supply : SupplyPower;
	}
	
	part def ArtificialHeart {
		doc /* 
			An artificial heart is a mechanical circulatory support device that replaces 
			the biological heart to maintain blood circulation throughout the body. 
			It pumps oxygenated blood to organs and tissues while returning deoxygenated 
			blood to the lungs, sustaining life for patients with end-stage heart failure.
		*/
		
		port systemicInlet : BloodInletPort {
			doc /* Receives deoxygenated blood from the systemic circulation */
		}
		
		port systemicOutlet : BloodOutletPort {
			doc /* Delivers oxygenated blood to the systemic circulation */
		}
		
		port pulmonaryInlet : BloodInletPort {
			doc /* Receives oxygenated blood from the pulmonary circulation */
		}
		
		port pulmonaryOutlet : BloodOutletPort {
			doc /* Delivers deoxygenated blood to the pulmonary circulation */
		}
		
		port externalPower : PowerPort;
		port controlPort : ControlSignalPort;
		
		part leftVentricle : PumpChamber {
			doc /* Pumps oxygenated blood to the systemic circulation */
		}
		
		part rightVentricle : PumpChamber {
			doc /* Pumps deoxygenated blood to the pulmonary circulation */
		}
		
		part mitralValve : Valve {
			doc /* Controls blood flow into left ventricle from pulmonary veins */
		}
		
		part aorticValve : Valve {
			doc /* Controls blood flow out of left ventricle to aorta */
		}
		
		part tricuspidValve : Valve {
			doc /* Controls blood flow into right ventricle from vena cava */
		}
		
		part pulmonaryValve : Valve {
			doc /* Controls blood flow out of right ventricle to pulmonary artery */
		}
		
		part drivingMotor : Motor {
			doc /* Provides mechanical power to drive both ventricles */
		}
		
		part powerSource : Battery {
			doc /* Provides electrical power to the system */
		}
		
		part systemController : Controller {
			doc /* Regulates pumping rate and monitors system health */
		}
		
		part pressureSensor : Sensor {
			doc /* Monitors blood pressure at critical points */
		}
		
		part flowSensor : Sensor {
			doc /* Monitors blood flow rates */
		}
		
		connect powerSource.powerOutput to drivingMotor.power;
		connect externalPower to powerSource.powerOutput;
		connect controlPort to systemController.controlInterface;
		connect pressureSensor.sensorOutput to systemController.sensorInput;
		connect flowSensor.sensorOutput to systemController.sensorInput;
		
		connect pulmonaryInlet to leftVentricle.inlet;
		connect leftVentricle.outlet to systemicOutlet;
		connect systemicInlet to rightVentricle.inlet;
		connect rightVentricle.outlet to pulmonaryOutlet;
		
		perform action pumpBlood : PumpBloodContinuously;
	}
	
	action def PumpBloodContinuously {
		in targetHeartRate : HeartRate;
		in targetPressure : BloodPressure;
		out systemicFlow : BloodFlowRate;
		out pulmonaryFlow : BloodFlowRate;
		out currentStatus : OperationalStatus;
		
		first start;
		then merge continuousPumping;
		
		then action monitorConditions {
			action measurePressure {
				out currentPressure : BloodPressure;
			}
			then action measureFlow {
				out currentFlow : BloodFlowRate;
			}
			then action checkBattery {
				out batteryState : BatteryLevel;
			}
		}
		
		then action regulateOperation {
			in pressure : BloodPressure = monitorConditions.measurePressure.currentPressure;
			in flowRate : BloodFlowRate = monitorConditions.measureFlow.currentFlow;
			in battery : BatteryLevel = monitorConditions.checkBattery.batteryState;
			out adjustedRate : HeartRate;
			out status : OperationalStatus;
		}
		
		then decide;
			if regulateOperation.status == OperationalStatus::normal then performCardiacCycle;
			if regulateOperation.status == OperationalStatus::warning then performCardiacCycle;
			if regulateOperation.status == OperationalStatus::critical then emergencyMode;
		
		action performCardiacCycle : CardiacCycle {
			in heartRate : HeartRate = regulateOperation.adjustedRate;
			out leftOutput : BloodFlowRate;
			out rightOutput : BloodFlowRate;
		}
		then continuousPumping;
		
		action emergencyMode {
			out alertSignal : OperationalStatus;
		}
		then done;
	}
	
	action def CardiacCycle {
		in heartRate : HeartRate;
		out leftOutput : BloodFlowRate;
		out rightOutput : BloodFlowRate;
		
		first start;
		
		then action diastolicPhase {
			doc /* Filling phase - ventricles relax and fill with blood */
			
			action openInletValves {
				out mitralOpen : ValveState;
				out tricuspidOpen : ValveState;
			}
			
			then action fillVentricles {
				in leftInflow : Blood;
				in rightInflow : Blood;
				out leftVolume : StrokeVolume;
				out rightVolume : StrokeVolume;
			}
			
			then action closeInletValves {
				out mitralClosed : ValveState;
				out tricuspidClosed : ValveState;
			}
		}
		
		then action systolicPhase {
			doc /* Ejection phase - ventricles contract and eject blood */
			
			action openOutletValves {
				out aorticOpen : ValveState;
				out pulmonaryOpen : ValveState;
			}
			
			then action contractVentricles {
				in motorTorque : ISQ::TorqueValue;
				out leftEjection : Blood;
				out rightEjection : Blood;
				out ejectionPressure : BloodPressure;
			}
			
			then action closeOutletValves {
				out aorticClosed : ValveState;
				out pulmonaryClosed : ValveState;
			}
		}
		
		then done;
	}
	
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def ReliabilityRequirement;
	
	requirement <'AH-001'> maintainCardiacOutput : PerformanceRequirement {
		doc /* 
			The artificial heart shall maintain a cardiac output between 4 and 8 liters per minute
			to ensure adequate blood circulation to all body organs and tissues under normal conditions.
		*/
		
		subject artificialHeart : ArtificialHeart;
		
		require constraint {
			artificialHeart.pumpBlood.systemicFlow >= 4.0 [L/min] and
			artificialHeart.pumpBlood.systemicFlow <= 8.0 [L/min]
		}
	}
	
	requirement <'AH-002'> regulateHeartRate : PerformanceRequirement {
		doc /* 
			The artificial heart shall regulate heart rate between 60 and 120 beats per minute
			based on physiological demand and sensor feedback to match metabolic needs.
		*/
		
		subject controller : Controller;
		
		require constraint {
			controller.pumpCommand >= 60.0 [1/min] and
			controller.pumpCommand <= 120.0 [1/min]
		}
	}
	
	requirement <'AH-003'> ensureBatteryLife : ReliabilityRequirement {
		doc /* 
			The battery shall provide continuous operation for at least 8 hours
			and alert when charge level falls below 20 percent to ensure patient safety.
		*/
		
		subject battery : Battery;
		
		assume constraint {
			battery.capacity >= 100.0 [W*h]
		}
		
		require constraint {
			battery.chargeLevel > 20.0
		}
	}
	
	requirement <'AH-004'> preventBackflow : SafetyRequirement {
		doc /* 
			The valves shall prevent backflow of blood by ensuring complete closure
			during the appropriate phase of the cardiac cycle to maintain unidirectional flow.
		*/
		
		subject valve : Valve;
	}
	
	requirement <'AH-005'> maintainBloodPressure : PerformanceRequirement {
		doc /* 
			The artificial heart shall maintain systemic arterial pressure
			between 90 and 140 mmHg to ensure proper organ perfusion without causing damage.
		*/
		
		subject heart : ArtificialHeart;
		
		require constraint {
			heart.systemicOutlet.outletPressure >= 90.0 [mmHg] and
			heart.systemicOutlet.outletPressure <= 140.0 [mmHg]
		}
	}
	
	requirement <'AH-SYS-001'> primaryFunction {
		doc /* 
			The artificial heart system shall continuously pump blood throughout the circulatory system,
			replacing the function of the biological heart by maintaining adequate cardiac output,
			regulating blood pressure, and responding to physiological demands to sustain life
			for patients with end-stage heart failure.
		*/
		
		subject system : ArtificialHeart;
		
		require maintainCardiacOutput;
		require regulateHeartRate;
		require maintainBloodPressure;
		require ensureBatteryLife;
		require preventBackflow;
	}
}
