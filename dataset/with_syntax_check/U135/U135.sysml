package 'Ventricular Assist Device System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BloodPressure :> ISQ::PressureValue {
		attribute systolic : ISQ::PressureValue;
		attribute diastolic : ISQ::PressureValue;
		attribute mean : ISQ::PressureValue;
	}
	
	attribute def BloodFlowRate :> ISQ::VolumeFlowRateValue;
	attribute def HeartRate :> ISQ::FrequencyValue;
	attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
	attribute def ElectricalPower :> ISQ::PowerValue;
	attribute def BatteryCharge :> ScalarValues::Real;
	attribute def AlarmCode :> ScalarValues::String;
	attribute def ElectricVoltage :> ISQ::ElectricPotentialDifferenceValue;
	attribute def DataCapacity :> ScalarValues::Real;
	
	item def Blood {
		attribute oxygenLevel : ScalarValues::Real;
		attribute viscosity : ISQ::DynamicViscosityValue;
	}
	
	port def BloodInletPort {
		in item bloodIn : Blood;
		in attribute pressureIn : BloodPressure;
		in attribute flowRateIn : BloodFlowRate;
	}
	
	port def BloodOutletPort {
		out item bloodOut : Blood;
		out attribute pressureOut : BloodPressure;
		out attribute flowRateOut : BloodFlowRate;
	}
	
	port def PowerPort {
		in attribute voltage : ElectricVoltage;
		in attribute current : ISQ::ElectricCurrentValue;
		out attribute powerDraw : ElectricalPower;
	}
	
	port def SensorPort {
		out attribute measuredPressure : BloodPressure;
		out attribute measuredFlowRate : BloodFlowRate;
		out attribute measuredHeartRate : HeartRate;
	}
	
	port def ControlPort {
		in attribute targetFlowRate : BloodFlowRate;
		in attribute operatingMode : ScalarValues::String;
		out attribute pumpSpeed : RotationalSpeed;
		out attribute systemStatus : ScalarValues::String;
	}
	
	part def VentricularAssistDevice {
		doc /* A mechanical circulatory support device that assists the heart in pumping blood 
		       throughout the body by augmenting cardiac output through continuous rotary flow. */
		
		port inletPort : BloodInletPort;
		port outletPort : BloodOutletPort;
		port powerInput : PowerPort;
		port sensorOutput : SensorPort;
		port controlInput : ControlPort;
		
		part pumpAssembly : PumpAssembly;
		part controlSystem : ControlSystem;
		part sensorArray : SensorArray;
		part powerModule : PowerModule;
		part cannulaSystem : CannulaSystem;
		
		connect inletPort to cannulaSystem.inletCannulaPort;
		connect cannulaSystem.pumpInletPort to pumpAssembly.inletPort;
		connect pumpAssembly.outletPort to cannulaSystem.pumpOutletPort;
		connect cannulaSystem.outletCannulaPort to outletPort;
		
		connect sensorArray.sensorOutput to controlSystem.sensorInput;
		connect controlSystem.controlOutput to pumpAssembly.controlInput;
		connect powerInput to powerModule.powerInput;
		connect powerModule.pumpPowerOutput to pumpAssembly.powerInput;
		connect powerModule.controlPowerOutput to controlSystem.powerInput;
		connect sensorOutput to sensorArray.sensorOutput;
		connect controlInput to controlSystem.controlInput;
		
		perform action provideCirculatorySupport;
	}
	
	part def PumpAssembly {
		doc /* Rotary blood pump that generates continuous flow through impeller rotation 
		       using magnetic levitation to minimize blood trauma. */
		
		port inletPort : BloodInletPort;
		port outletPort : BloodOutletPort;
		port powerInput : PowerPort;
		port controlInput : ControlPort;
		
		part impeller : Impeller;
		part motor : BrushlessMotor;
		part bearings : MagneticBearings;
		part housing : PumpHousing;
		
		attribute currentSpeed : RotationalSpeed;
		attribute currentFlowRate : BloodFlowRate;
		attribute targetSpeed : RotationalSpeed;
	}
	
	part def Impeller {
		doc /* Rotating component that imparts kinetic energy to blood. */
		attribute rotationSpeed : RotationalSpeed;
		attribute bladeCount : ScalarValues::Integer;
		attribute diameter : ISQ::LengthValue;
	}
	
	part def BrushlessMotor {
		doc /* Electric motor that drives the impeller rotation. */
		attribute motorSpeed : RotationalSpeed;
		attribute motorPower : ElectricalPower;
		attribute efficiency : ScalarValues::Real;
		attribute torque : ISQ::TorqueValue;
	}
	
	part def MagneticBearings {
		doc /* Contactless bearings that levitate the impeller to reduce friction and hemolysis. */
		attribute levitationGap : ISQ::LengthValue;
		attribute magneticFieldStrength : ISQ::MagneticFluxDensityValue;
	}
	
	part def PumpHousing {
		doc /* Biocompatible enclosure for pump components. */
		attribute biocompatible : ScalarValues::Boolean;
		attribute material : ScalarValues::String;
	}
	
	part def ControlSystem {
		doc /* Microprocessor-based control system that regulates pump speed based on 
		       physiological feedback and operating mode. */
		
		port sensorInput : SensorPort;
		port controlInput : ControlPort;
		port controlOutput : ControlPort;
		port powerInput : PowerPort;
		
		part processor : Microprocessor;
		part algorithm : ControlAlgorithm;
		part alarmManager : AlarmManager;
		
		attribute targetFlowRate : BloodFlowRate;
		attribute currentPumpSpeed : RotationalSpeed;
		attribute operatingMode : ScalarValues::String;
		
		perform action regulatePumpOperation;
	}
	
	part def Microprocessor {
		attribute processingSpeed : ISQ::FrequencyValue;
		attribute memoryCapacity : DataCapacity;
	}
	
	part def ControlAlgorithm {
		doc /* Implements physiologic control strategies including fixed speed, 
		       pulsatility index, and flow-based control. */
		attribute algorithmType : ScalarValues::String;
		attribute gainParameter : ScalarValues::Real;
	}
	
	part def AlarmManager {
		doc /* Monitors system parameters and generates alarms for fault conditions. */
		attribute activeAlarms : AlarmCode[*];
		perform action monitorAlarms;
	}
	
	part def SensorArray {
		doc /* Collection of sensors monitoring hemodynamic and system parameters. */
		
		port sensorOutput : SensorPort;
		
		part pressureSensor : PressureSensor;
		part flowSensor : FlowSensor;
		part heartRateSensor : HeartRateSensor;
		part temperatureSensor : TemperatureSensor;
	}
	
	part def PressureSensor {
		out attribute pressure : BloodPressure;
		attribute accuracy : ISQ::PressureValue;
	}
	
	part def FlowSensor {
		out attribute flowRate : BloodFlowRate;
		attribute accuracy : ISQ::VolumeFlowRateValue;
	}
	
	part def HeartRateSensor {
		out attribute heartRate : HeartRate;
		attribute accuracy : ISQ::FrequencyValue;
	}
	
	part def TemperatureSensor {
		out attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute accuracy : ISQ::ThermodynamicTemperatureValue;
	}
	
	part def PowerModule {
		doc /* Manages power distribution from external battery or controller to device components. */
		
		port powerInput : PowerPort;
		port pumpPowerOutput : PowerPort;
		port controlPowerOutput : PowerPort;
		
		part battery : Battery;
		part powerConverter : PowerConverter;
		part backupBattery : Battery;
		
		perform action managePower;
	}
	
	part def Battery {
		attribute capacity : ISQ::EnergyValue;
		attribute voltage : ElectricVoltage;
		attribute chargeLevel : BatteryCharge;
		attribute remainingTime : ISQ::TimeValue;
	}
	
	part def PowerConverter {
		attribute inputVoltage : ElectricVoltage;
		attribute outputVoltage : ElectricVoltage;
		attribute efficiency : ScalarValues::Real;
	}
	
	part def CannulaSystem {
		doc /* Tubes that connect the VAD to the heart and aorta. */
		
		port inletCannulaPort : BloodInletPort;
		port pumpInletPort : BloodOutletPort;
		port pumpOutletPort : BloodInletPort;
		port outletCannulaPort : BloodOutletPort;
		
		part inletCannula : Cannula;
		part outletCannula : Cannula;
	}
	
	part def Cannula {
		attribute diameter : ISQ::LengthValue;
		attribute length : ISQ::LengthValue;
		attribute material : ScalarValues::String;
		attribute biocompatible : ScalarValues::Boolean;
	}
	
	action def MonitorHemodynamics {
		in attribute currentPressure : BloodPressure;
		in attribute currentFlowRate : BloodFlowRate;
		in attribute currentHeartRate : HeartRate;
		out attribute hemodynamicStatus : ScalarValues::String;
		out attribute pressureGradient : ISQ::PressureValue;
	}
	
	action def CalculateTargetSpeed {
		in attribute targetFlow : BloodFlowRate;
		in attribute currentPressure : BloodPressure;
		in attribute operatingMode : ScalarValues::String;
		out attribute commandedSpeed : RotationalSpeed;
	}
	
	action def AdjustPumpSpeed {
		in attribute commandedSpeed : RotationalSpeed;
		in attribute currentSpeed : RotationalSpeed;
		out attribute motorCommand : ElectricalPower;
		out attribute speedAdjustment : RotationalSpeed;
	}
	
	action def PumpBlood {
		in attribute inletPressure : BloodPressure;
		in attribute pumpSpeed : RotationalSpeed;
		in item bloodIn : Blood;
		out attribute outletPressure : BloodPressure;
		out attribute flowRate : BloodFlowRate;
		out item bloodOut : Blood;
	}
	
	action def CheckBatteryLevel {
		in attribute currentCharge : BatteryCharge;
		out attribute batteryStatus : ScalarValues::String;
		out attribute lowBatteryAlarm : ScalarValues::Boolean;
	}
	
	action def GenerateAlarm {
		in attribute alarmCondition : ScalarValues::String;
		out attribute alarmCode : AlarmCode;
		out attribute alarmSeverity : ScalarValues::String;
	}
	
	action def regulatePumpOperation {
		doc /* Continuously monitors patient hemodynamics and adjusts pump speed to maintain 
		       adequate blood flow while responding to physiological changes. */
		
		first start;
		then merge continuousRegulation;
		
		then action monitor : MonitorHemodynamics {
			in currentPressure : BloodPressure;
			in currentFlowRate : BloodFlowRate;
			in currentHeartRate : HeartRate;
			out hemodynamicStatus : ScalarValues::String;
			out pressureGradient : ISQ::PressureValue;
		}
		
		then decide;
			if monitor.hemodynamicStatus == "normal" then normalOperation;
			if monitor.hemodynamicStatus == "low_flow" then increaseSpeed;
			if monitor.hemodynamicStatus == "high_pressure" then decreaseSpeed;
		
		action normalOperation : CalculateTargetSpeed {
			in targetFlow : BloodFlowRate;
			in currentPressure = monitor.currentPressure;
			in operatingMode : ScalarValues::String;
			out commandedSpeed : RotationalSpeed;
		}
		then adjustmentMerge;
		
		action increaseSpeed : CalculateTargetSpeed {
			in targetFlow : BloodFlowRate;
			in currentPressure = monitor.currentPressure;
			in operatingMode = "boost";
			out commandedSpeed : RotationalSpeed;
		}
		then adjustmentMerge;
		
		action decreaseSpeed : CalculateTargetSpeed {
			in targetFlow : BloodFlowRate;
			in currentPressure = monitor.currentPressure;
			in operatingMode = "reduce";
			out commandedSpeed : RotationalSpeed;
		}
		then adjustmentMerge;
		
		merge adjustmentMerge;
		
		then action adjustSpeed : AdjustPumpSpeed {
			in commandedSpeed : RotationalSpeed;
			in currentSpeed : RotationalSpeed;
			out motorCommand : ElectricalPower;
			out speedAdjustment : RotationalSpeed;
		}
		
		then continuousRegulation;
	}
	
	action def managePower {
		doc /* Monitors battery levels and manages power distribution with automatic 
		       switchover to backup battery when needed. */
		
		first start;
		then merge powerLoop;
		
		then action checkBattery : CheckBatteryLevel {
			in currentCharge : BatteryCharge;
			out batteryStatus : ScalarValues::String;
			out lowBatteryAlarm : ScalarValues::Boolean;
		}
		
		then decide;
			if checkBattery.lowBatteryAlarm then generateLowBatteryAlarm;
			if not checkBattery.lowBatteryAlarm then continuePower;
		
		action generateLowBatteryAlarm : GenerateAlarm {
			in alarmCondition = "low_battery";
			out alarmCode : AlarmCode;
			out alarmSeverity = "high";
		}
		then powerMerge;
		
		action continuePower;
		then powerMerge;
		
		merge powerMerge;
		then powerLoop;
	}
	
	action def monitorAlarms {
		doc /* Continuously monitors system parameters and generates alarms for fault conditions. */
		
		first start;
		then merge alarmLoop;
		
		then action checkSystemParameters {
			in flowRate : BloodFlowRate;
			in pressure : BloodPressure;
			in batteryCharge : BatteryCharge;
			in pumpSpeed : RotationalSpeed;
			out faultDetected : ScalarValues::Boolean;
			out faultType : ScalarValues::String;
		}
		
		then decide;
			if checkSystemParameters.faultDetected then raiseAlarm;
			if not checkSystemParameters.faultDetected then continueMonitoring;
		
		action raiseAlarm : GenerateAlarm {
			in alarmCondition = checkSystemParameters.faultType;
			out alarmCode : AlarmCode;
			out alarmSeverity : ScalarValues::String;
		}
		then alarmMerge;
		
		action continueMonitoring;
		then alarmMerge;
		
		merge alarmMerge;
		then alarmLoop;
	}
	
	action def provideCirculatorySupport {
		doc /* Primary function: augment cardiac output by continuously pumping blood from 
		       the left ventricle to the aorta, maintaining adequate systemic perfusion. */
		
		in attribute inletBloodPressure : BloodPressure;
		in attribute powerSupply : ElectricalPower;
		in item inletBlood : Blood;
		out attribute outletBloodPressure : BloodPressure;
		out attribute achievedFlowRate : BloodFlowRate;
		out item outletBlood : Blood;
		
		first start;
		
		then action initializeSystem {
			action powerUp {
				doc /* Power up all system components. */
			}
			then action selfTest {
				doc /* Perform system self-test and diagnostics. */
			}
			then action calibrateSensors {
				doc /* Calibrate all sensors to baseline values. */
			}
			then action setInitialSpeed {
				doc /* Set pump to initial operating speed. */
			}
		}
		
		then action continuousOperation {
			loop {
				action senseConditions : MonitorHemodynamics {
					in currentPressure = inletBloodPressure;
					in currentFlowRate : BloodFlowRate;
					in currentHeartRate : HeartRate;
					out hemodynamicStatus : ScalarValues::String;
					out pressureGradient : ISQ::PressureValue;
				}
				
				flow senseConditions.hemodynamicStatus to determineSpeed.operatingMode;
				
				action determineSpeed : CalculateTargetSpeed {
					in targetFlow : BloodFlowRate;
					in currentPressure = inletBloodPressure;
					in operatingMode : ScalarValues::String;
					out commandedSpeed : RotationalSpeed;
				}
				
				flow determineSpeed.commandedSpeed to pumpBlood.pumpSpeed;
				
				action pumpBlood : PumpBlood {
					in inletPressure = inletBloodPressure;
					in pumpSpeed : RotationalSpeed;
					in bloodIn = inletBlood;
					out outletPressure : BloodPressure;
					out flowRate : BloodFlowRate;
					out bloodOut : Blood;
				}
				
				then assign outletBloodPressure := pumpBlood.outletPressure;
				then assign achievedFlowRate := pumpBlood.flowRate;
				then assign outletBlood := pumpBlood.bloodOut;
				
				action monitorPower : CheckBatteryLevel {
					in currentCharge : BatteryCharge;
					out batteryStatus : ScalarValues::String;
					out lowBatteryAlarm : ScalarValues::Boolean;
				}
				
				then decide;
					if monitorPower.lowBatteryAlarm then alertLowBattery;
					if not monitorPower.lowBatteryAlarm then continueLoop;
				
				action alertLowBattery : GenerateAlarm {
					in alarmCondition = "critical_battery";
					out alarmCode : AlarmCode;
					out alarmSeverity = "critical";
				}
				then loopMerge;
				
				action continueLoop;
				then loopMerge;
				
				merge loopMerge;
			}
		}
	}
	
	requirement def VADSystemRequirements {
		doc /* Top-level requirements for ventricular assist device system. */
		
		requirement functionalRequirements {
			doc /* The VAD shall provide circulatory support by augmenting cardiac output. */
			
			requirement <'VAD-FR-001'> flowRateRequirement {
				doc /* The VAD shall maintain blood flow rate between 3 and 10 liters per minute 
				       adjustable based on patient physiological demand. */
			}
			
			requirement <'VAD-FR-002'> pressureRequirement {
				doc /* The VAD shall generate sufficient pressure differential (minimum 60 mmHg) 
				       to overcome systemic vascular resistance. */
			}
			
			requirement <'VAD-FR-003'> continuousOperationRequirement {
				doc /* The VAD shall operate continuously for extended periods (minimum 2 years) 
				       without mechanical failure. */
			}
			
			requirement <'VAD-FR-004'> responseTimeRequirement {
				doc /* The VAD control system shall respond to hemodynamic changes within 2 seconds. */
			}
		}
		
		requirement safetyRequirements {
			doc /* Safety-critical requirements for patient protection. */
			
			requirement <'VAD-SR-001'> biocompatibilityRequirement {
				doc /* All blood-contacting surfaces shall be biocompatible to minimize thrombosis 
				       and hemolysis (hemolysis index < 0.01 g/100L). */
			}
			
			requirement <'VAD-SR-002'> alarmRequirement {
				doc /* The VAD shall provide audible and visual alarms for critical fault conditions 
				       including low battery, pump failure, and abnormal hemodynamics. */
			}
			
			requirement <'VAD-SR-003'> backupPowerRequirement {
				doc /* The VAD shall include backup power to maintain operation for minimum 30 minutes 
				       during primary power failure. */
			}
			
			requirement <'VAD-SR-004'> failSafeRequirement {
				doc /* The VAD shall enter a safe state with audible alarm in case of critical 
				       system failure. */
			}
		}
		
		requirement performanceRequirements {
			doc /* Performance specifications for device operation. */
			
			requirement <'VAD-PR-001'> efficiencyRequirement {
				doc /* The pump shall operate with hydraulic efficiency greater than 25 percent 
				       across the operating range. */
			}
			
			requirement <'VAD-PR-002'> powerConsumptionRequirement {
				doc /* The VAD shall consume less than 15 watts of electrical power at nominal 
				       operating conditions. */
			}
			
			requirement <'VAD-PR-003'> batteryLifeRequirement {
				doc /* The primary battery shall provide minimum 8 hours of continuous operation 
				       at nominal flow rate. */
			}
			
			requirement <'VAD-PR-004'> noiseRequirement {
				doc /* The VAD shall operate with acoustic noise level below 40 dB at 1 meter distance. */
			}
		}
	}
	
	requirement vadSystemRequirements : VADSystemRequirements;
	
	part vadSystem : VentricularAssistDevice {
		doc /* Instance of ventricular assist device providing left ventricular support 
		       for patients with advanced heart failure. */
		
		satisfy vadSystemRequirements;
		
		perform action provideCirculatorySupport {
			in inletBloodPressure : BloodPressure;
			in powerSupply : ElectricalPower;
			in inletBlood : Blood;
			out outletBloodPressure : BloodPressure;
			out achievedFlowRate : BloodFlowRate;
			out outletBlood : Blood;
		}
	}
}
