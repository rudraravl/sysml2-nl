package NdYAGLaserSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Wavelength :> ISQ::LengthValue;
	attribute def OpticalPower :> ISQ::PowerValue;
	attribute def PulseEnergy :> ISQ::EnergyValue;
	attribute def RepetitionRate :> ISQ::FrequencyValue;
	attribute def BeamDivergence :> ISQ::LengthValue;
	attribute def FlowRate :> ISQ::VolumeFlowRateValue;
	attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
	attribute def Voltage :> ISQ::ElectricPotentialValue;
	attribute def Current :> ISQ::ElectricCurrentValue;
	
	enum def OperatingMode {
		continuousWave;
		pulsed;
		qSwitched;
	}
	
	enum def SystemState {
		off;
		initializing;
		standby;
		active;
		cooling;
		fault;
	}
	
	item def LaserBeam {
		attribute wavelength : Wavelength;
		attribute power : OpticalPower;
		attribute divergence : BeamDivergence;
	}
	
	item def ElectricalPower {
		attribute voltage : Voltage;
		attribute current : Current;
	}
	
	item def Coolant {
		attribute flowRate : FlowRate;
		attribute inletTemperature : Temperature;
		attribute outletTemperature : Temperature;
	}
	
	port def ElectricalPort {
		in item electricalPower : ElectricalPower;
	}
	
	port def CoolantPort {
		in item coolantIn : Coolant;
		out item coolantOut : Coolant;
	}
	
	port def OpticalPort {
		out item beam : LaserBeam;
	}
	
	port def ControlPort {
		in attribute modeCommand : OperatingMode;
		in attribute powerLevel : OpticalPower;
		out attribute currentState : SystemState;
		out attribute measuredPower : OpticalPower;
	}
	
	part def PowerSupply {
		doc /* Converts AC mains power to regulated DC for flashlamp and control electronics */
		port electricalInput : ElectricalPort;
		port flashlampOutput : ElectricalPort;
		port controlOutput : ElectricalPort;
		
		attribute inputVoltage : Voltage = 220[V];
		attribute flashlampVoltage : Voltage = 800[V];
		attribute maxCurrent : Current = 50[A];
		
		action def ConvertPower {
			in acInput : ElectricalPower;
			out dcFlashlamp : ElectricalPower;
			out dcControl : ElectricalPower;
		}
	}
	
	part def FlashlampPump {
		doc /* Xenon flashlamp that optically pumps the Nd:YAG crystal */
		port power : ElectricalPort;
		port cooling : CoolantPort;
		
		attribute pulseEnergy : PulseEnergy = 50[J];
		attribute pulseWidth : ISQ::TimeValue = 200e-6[s];
		attribute repetitionRate : RepetitionRate = 10[Hz];
		
		action def GeneratePumpLight {
			in electrical : ElectricalPower;
			out pumpPower : OpticalPower;
		}
		
		perform action emitPump : GeneratePumpLight;
	}
	
	part def NdYAGCrystal {
		doc /* Neodymium-doped yttrium aluminum garnet gain medium */
		attribute dopingLevel : ScalarValues::Real = 1.1;
		attribute crystalLength : ISQ::LengthValue = 100[mm];
		attribute diameter : ISQ::LengthValue = 6[mm];
		attribute emissionWavelength : Wavelength = 1064[nm];
		
		action def AbsorbPumpEnergy {
			in pumpPower : OpticalPower;
			out populationInversion : ScalarValues::Real;
		}
		
		action def AmplifyLight {
			in seedPhotons : ScalarValues::Real;
			in inversion : ScalarValues::Real;
			out amplifiedPhotons : ScalarValues::Real;
		}
	}
	
	part def OpticalResonator {
		doc /* Optical cavity formed by high reflector and output coupler mirrors */
		part highReflector : ResonatorMirror {
			attribute :>> reflectivity = 0.999;
			attribute :>> radius = 5000[mm];
		}
		
		part outputCoupler : ResonatorMirror {
			attribute :>> reflectivity = 0.65;
			attribute :>> radius = 3000[mm];
		}
		
		attribute cavityLength : ISQ::LengthValue = 500[mm];
		
		action def BuildOscillation {
			in gainPhotons : ScalarValues::Real;
			out cavityPhotons : ScalarValues::Real;
		}
	}
	
	part def ResonatorMirror {
		attribute reflectivity : ScalarValues::Real;
		attribute radius : ISQ::LengthValue;
		attribute coating : ScalarValues::String;
	}
	
	part def QSwitch {
		doc /* Electro-optic modulator for generating high-energy pulses */
		port control : ElectricalPort;
		
		attribute switchingTime : ISQ::TimeValue = 10e-9[s];
		attribute holdoffVoltage : Voltage = 3000[V];
		
		action def ModulateCavity {
			in controlSignal : Voltage;
			out cavityQFactor : ScalarValues::Real;
		}
		
		perform action modulate : ModulateCavity;
	}
	
	part def CoolingSystem {
		doc /* Closed-loop water cooling for thermal management */
		port coolantInput : CoolantPort;
		port coolantOutput : CoolantPort;
		port power : ElectricalPort;
		
		attribute flowRate : FlowRate = 10[L/min];
		attribute coolingCapacity : ISQ::PowerValue = 2000[W];
		attribute targetTemperature : Temperature = 293.15[K];
		
		action def CirculateCoolant {
			in heatLoad : ISQ::PowerValue;
			in flowRate : FlowRate;
			out outletTemp : Temperature;
		}
		
		perform action cool : CirculateCoolant;
	}
	
	part def BeamDelivery {
		doc /* Beam shaping and steering optics */
		port opticalInput : OpticalPort;
		port opticalOutput : OpticalPort;
		
		attribute expansionRatio : ScalarValues::Real = 3.0;
		attribute transmissionEfficiency : ScalarValues::Real = 0.95;
		
		action def ShapeBeam {
			in inputBeam : LaserBeam;
			out outputBeam : LaserBeam;
		}
		
		perform action shape : ShapeBeam;
	}
	
	part def LaserController {
		doc /* Electronic control system managing laser operation */
		port control : ControlPort;
		port powerControl : ElectricalPort;
		port qSwitchControl : ElectricalPort;
		
		attribute operatingMode : OperatingMode = OperatingMode::qSwitched;
		attribute targetPower : OpticalPower = 100[W];
		attribute currentState : SystemState = SystemState::off;
		
		action def MonitorAndRegulate {
			in measuredPower : OpticalPower;
			in targetPower : OpticalPower;
			out adjustment : Voltage;
		}
		
		perform action regulate : MonitorAndRegulate;
	}
	
	part def PowerMeter {
		doc /* Optical power measurement and monitoring */
		port opticalSample : OpticalPort;
		port dataOutput : ElectricalPort;
		
		attribute measuredPower : OpticalPower;
		attribute accuracy : ScalarValues::Real = 0.02;
		
		action def MeasurePower {
			in beam : LaserBeam;
			out power : OpticalPower;
		}
		
		perform action measure : MeasurePower;
	}
	
	part def NdYAGLaser {
		doc /* Complete Nd:YAG laser system for high-power coherent light generation at 1064 nm */
		
		port mainPower : ElectricalPort;
		port coolantIn : CoolantPort;
		port coolantOut : CoolantPort;
		port laserOutput : OpticalPort;
		port systemControl : ControlPort;
		
		part psu : PowerSupply;
		
		part flashlamp : FlashlampPump;
		
		part crystal : NdYAGCrystal;
		
		part resonator : OpticalResonator;
		
		part qSwitch : QSwitch;
		
		part cooling : CoolingSystem;
		
		part beamOptics : BeamDelivery;
		
		part controller : LaserController;
		
		part powerMeter : PowerMeter;
		
		binding mainPower = psu.electricalInput;
		binding psu.flashlampOutput = flashlamp.power;
		binding psu.controlOutput = qSwitch.control;
		binding psu.controlOutput = cooling.power;
		binding coolantIn = cooling.coolantInput;
		binding coolantOut = cooling.coolantOutput;
		binding flashlamp.cooling = cooling.coolantInput;
		binding beamOptics.opticalOutput = laserOutput;
		binding systemControl = controller.control;
		binding controller.qSwitchControl = qSwitch.control;
		
		perform action generateLaser : GenerateCoherentLight;
		
		state laserStateMachine : LaserOperatingStates;
	}
	
	action def GenerateCoherentLight {
		doc /* Primary function: Generate high-power coherent optical radiation at 1064 nm wavelength */
		
		in electricalInput : ElectricalPower;
		in coolantFlow : Coolant;
		in operatingMode : OperatingMode;
		in targetPower : OpticalPower;
		out laserOutput : LaserBeam;
		
		first start;
		then merge readyCheck;
		
		action initialize {
			doc /* Initialize all subsystems and verify readiness */
		}
		then readyCheck;
		
		decide;
			if true then startLasing;
		
		action startLasing {
			action pumpCrystal {
				doc /* Flashlamp optically pumps Nd:YAG crystal to create population inversion */
				in flashEnergy : PulseEnergy;
				out inversionLevel : ScalarValues::Real;
			}
			
			action buildCavityField {
				doc /* Photons oscillate in optical cavity, building intensity */
				in populationInversion : ScalarValues::Real;
				out cavityIntensity : ScalarValues::Real;
			}
			
			action releaseQSwitch {
				doc /* Q-switch opens, releasing stored energy as high-power pulse */
				in qSwitchSignal : Voltage;
				out pulseReleased : ScalarValues::Boolean;
			}
			
			action extractOutput {
				doc /* Output coupler transmits portion of cavity field as laser beam */
				in cavityField : ScalarValues::Real;
				out outputBeam : LaserBeam;
			}
			
			action monitorPower {
				doc /* Measure output power and adjust pump energy */
				in measured : OpticalPower;
				in target : OpticalPower;
				out correction : Voltage;
			}
			
			action manageThermal {
				doc /* Circulate coolant to maintain crystal temperature */
				in heatLoad : ISQ::PowerValue;
				in coolant : Coolant;
				out temperature : Temperature;
			}
		}
		then readyCheck;
	}
	
	state def LaserOperatingStates {
		entry; then off;
		
		state off {
			entry assign controller.currentState := SystemState::off;
		}
		
		transition powerOn
			first off
			accept powerCommand
			then initializing;
		
		state initializing {
			entry assign controller.currentState := SystemState::initializing;
			do action warmUp {
				in duration : ISQ::TimeValue = 60[s];
			}
		}
		
		transition initComplete
			first initializing
			accept systemReady
			then standby;
		
		state standby {
			entry assign controller.currentState := SystemState::standby;
		}
		
		transition enableLaser
			first standby
			accept laserEnable
			then active;
		
		state active {
			entry assign controller.currentState := SystemState::active;
			do action lase : GenerateCoherentLight;
		}
		
		transition disableLaser
			first active
			accept laserDisable
			then cooling;
		
		state cooling {
			entry assign controller.currentState := SystemState::cooling;
			do action coolDown {
				in duration : ISQ::TimeValue = 120[s];
			}
		}
		
		transition coolComplete
			first cooling
			accept coolingComplete
			then standby;
		
		transition faultDetected
			first standby, active, cooling
			accept faultSignal
			then fault;
		
		state fault {
			entry assign controller.currentState := SystemState::fault;
		}
		
		transition faultCleared
			first fault
			accept clearFault
			then off;
		
		transition emergencyShutdown
			first off, initializing, standby, active, cooling
			accept emergencyStop
			then off;
	}
	
	requirement def LaserSystemRequirement;
	
	requirement <'REQ-001'> outputWavelength : LaserSystemRequirement {
		doc /* The laser shall emit coherent radiation at the fundamental Nd:YAG wavelength of 1064 nm */
		subject laser : NdYAGLaser;
		
		require constraint {
			laser.laserOutput.beam.wavelength == 1064[nm]
		}
	}
	
	requirement <'REQ-002'> minimumPower : LaserSystemRequirement {
		doc /* The laser shall deliver a minimum average output power of 100 W in continuous operation */
		subject laser : NdYAGLaser;
		
		require constraint {
			laser.laserOutput.beam.power >= 100[W]
		}
	}
	
	requirement <'REQ-003'> pulseEnergy : LaserSystemRequirement {
		doc /* In Q-switched mode, the laser shall deliver pulses with minimum energy of 1 J */
		subject laser : NdYAGLaser;
		
		require constraint {
			laser.qSwitch.modulate.cavityQFactor >= 100.0
		}
	}
	
	requirement <'REQ-004'> thermalStability : LaserSystemRequirement {
		doc /* The cooling system shall maintain crystal temperature within ±2 K of target */
		subject cooling : CoolingSystem;
		
		require constraint {
			abs(cooling.cool.outletTemp - cooling.targetTemperature) <= 2[K]
		}
	}
	
	requirement <'REQ-005'> beamQuality : LaserSystemRequirement {
		doc /* The output beam divergence shall not exceed 2 mrad for proper focusing */
		subject laser : NdYAGLaser;
		
		require constraint {
			laser.laserOutput.beam.divergence <= 0.002[m]
		}
	}
	
	requirement <'REQ-006'> efficiency : LaserSystemRequirement {
		doc /* The overall wall-plug efficiency shall be at least 3% */
		subject laser : NdYAGLaser;
		
		require constraint {
			laser.laserOutput.beam.power / (laser.mainPower.electricalPower.voltage * laser.mainPower.electricalPower.current) >= 0.03
		}
	}
}
