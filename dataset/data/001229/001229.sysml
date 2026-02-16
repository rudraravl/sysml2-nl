package 'Rotary Variable Differential Transformer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		attribute def AngularPosition :> AngleValue;
		attribute def ExcitationVoltage :> VoltageValue;
		attribute def OutputVoltage :> VoltageValue;
		attribute def CarrierFrequency :> FrequencyValue;
		attribute def WireResistance :> ElectricResistanceValue;
		attribute def CoilInductance :> InductanceValue;
		attribute def OperatingTemperature :> ThermodynamicTemperatureValue;
		attribute def LinearityError :> Real;
		
		port def RotationalInputPort {
			in attribute shaftAngle : AngularPosition;
		}
		
		port def ExcitationInputPort {
			in attribute voltage : ExcitationVoltage;
			in attribute frequency : CarrierFrequency;
		}
		
		port def DifferentialOutputPort {
			out attribute primaryOutput : OutputVoltage;
			out attribute secondaryOutput : OutputVoltage;
		}
		
		port def AngleOutputPort {
			out attribute measuredAngle : AngularPosition;
		}
		
		part def PrimaryCoil {
			port excitationIn : ExcitationInputPort;
			attribute resistance : WireResistance;
			attribute inductance : CoilInductance;
			attribute turnsCount : Integer;
		}
		
		part def RotorAssembly {
			port rotationalInput : RotationalInputPort;
			attribute currentPosition : AngularPosition;
			attribute coreMaterial : String;
			attribute magneticPermeability : Real;
		}
		
		part def SecondaryCoilPair {
			attribute coilID : Integer;
			attribute resistance : WireResistance;
			attribute inductance : CoilInductance;
			attribute turnsCount : Integer;
			attribute couplingFactor : Real;
			out attribute inducedVoltage : OutputVoltage;
		}
		
		part def DemodulatorCircuit {
			in attribute primarySignal : OutputVoltage;
			in attribute secondarySignal : OutputVoltage;
			in attribute carrierFrequency : CarrierFrequency;
			out attribute demodulatedAmplitude : VoltageValue;
			out attribute demodulatedPhase : AngleValue;
		}
		
		part def AngleCalculator {
			in attribute amplitude : VoltageValue;
			in attribute phase : AngleValue;
			out attribute calculatedAngle : AngularPosition;
			attribute calibrationCoefficients : Real[8];
			attribute temperatureCompensation : Real;
		}
		
		action def ApplyExcitation {
			in excitationVoltage : ExcitationVoltage;
			in excitationFrequency : CarrierFrequency;
			out primaryMagneticFlux : Real;
		}
		
		action def TransferMagneticCoupling {
			in rotorPosition : AngularPosition;
			in primaryFlux : Real;
			out coil1Coupling : Real;
			out coil2Coupling : Real;
		}
		
		action def InduceSecondaryVoltages {
			in coil1Coupling : Real;
			in coil2Coupling : Real;
			in excitationAmplitude : ExcitationVoltage;
			out primaryVoltage : OutputVoltage;
			out secondaryVoltage : OutputVoltage;
		}
		
		action def DemodulateSignals {
			in primarySignal : OutputVoltage;
			in secondarySignal : OutputVoltage;
			in carrier : CarrierFrequency;
			out amplitude : VoltageValue;
			out phase : AngleValue;
		}
		
		action def CalculateAngle {
			in amplitude : VoltageValue;
			in phase : AngleValue;
			out angle : AngularPosition;
		}
		
		action def MeasureAngularPosition {
			in shaftAngle : AngularPosition;
			in excitationVoltage : ExcitationVoltage;
			in excitationFrequency : CarrierFrequency;
			out measuredAngle : AngularPosition;
			
			first start;
			
			then action applyExcitation : ApplyExcitation {
				in excitationVoltage = MeasureAngularPosition::excitationVoltage;
				in excitationFrequency = MeasureAngularPosition::excitationFrequency;
				out primaryMagneticFlux : Real;
			}
			
			flow applyExcitation.primaryMagneticFlux to transferCoupling.primaryFlux;
			
			then action transferCoupling : TransferMagneticCoupling {
				in rotorPosition = MeasureAngularPosition::shaftAngle;
				in primaryFlux : Real;
				out coil1Coupling : Real;
				out coil2Coupling : Real;
			}
			
			flow transferCoupling.coil1Coupling to induceVoltages.coil1Coupling;
			flow transferCoupling.coil2Coupling to induceVoltages.coil2Coupling;
			
			then action induceVoltages : InduceSecondaryVoltages {
				in coil1Coupling : Real;
				in coil2Coupling : Real;
				in excitationAmplitude = MeasureAngularPosition::excitationVoltage;
				out primaryVoltage : OutputVoltage;
				out secondaryVoltage : OutputVoltage;
			}
			
			flow induceVoltages.primaryVoltage to demodulate.primarySignal;
			flow induceVoltages.secondaryVoltage to demodulate.secondarySignal;
			
			then action demodulate : DemodulateSignals {
				in primarySignal : OutputVoltage;
				in secondarySignal : OutputVoltage;
				in carrier = MeasureAngularPosition::excitationFrequency;
				out amplitude : VoltageValue;
				out phase : AngleValue;
			}
			
			flow demodulate.amplitude to calculate.amplitude;
			flow demodulate.phase to calculate.phase;
			
			then action calculate : CalculateAngle {
				in amplitude : VoltageValue;
				in phase : AngleValue;
				out angle : AngularPosition;
			}
			
			then assign measuredAngle := calculate.angle;
			
			then done;
		}
		
		requirement def AccuracyRequirement {
			doc /* The RVDT shall provide angular position measurement with specified linearity error. */
			subject rvdt : RVDTTransducer;
			require constraint {
				rvdt.linearityError <= 0.5
			}
		}
		
		requirement def OperationalRangeRequirement {
			doc /* The RVDT shall operate over full 360 degree rotational range. */
			subject rvdt : RVDTTransducer;
			require constraint {
				rvdt.mechanicalInput.shaftAngle >= 0.0 and
				rvdt.mechanicalInput.shaftAngle <= 360.0
			}
		}
		
		requirement def TemperatureStabilityRequirement {
			doc /* The RVDT shall maintain measurement accuracy over specified temperature range. */
			subject rvdt : RVDTTransducer;
			require constraint {
				rvdt.operatingTemperature >= 218.15 and
				rvdt.operatingTemperature <= 398.15
			}
		}
		
		requirement def ExcitationFrequencyRequirement {
			doc /* The RVDT shall operate with AC excitation in specified frequency range. */
			subject rvdt : RVDTTransducer;
			require constraint {
				rvdt.excitationInput.frequency >= 400.0 and
				rvdt.excitationInput.frequency <= 20000.0
			}
		}
		
		part def RVDTTransducer {
			doc /* 
				Rotary Variable Differential Transformer for contactless angular position sensing.
				
				The RVDT is an electromechanical transducer that converts angular displacement 
				into an electrical signal through electromagnetic induction. It consists of a 
				primary coil energized by AC excitation, a rotating ferromagnetic core, and 
				two secondary coils arranged symmetrically. As the rotor rotates, the magnetic 
				coupling between primary and secondary coils varies sinusoidally with angular 
				position, producing differential AC voltages proportional to shaft angle. 
				Signal processing demodulates these voltages to extract precise angular position, 
				enabling non-contact, wear-free measurement suitable for aerospace, robotics, 
				and precision control applications.
			*/
			
			attribute linearityError : LinearityError;
			attribute operatingTemperature : OperatingTemperature;
			attribute nullVoltage : VoltageValue;
			attribute sensitivity : Real;
			
			port mechanicalInput : RotationalInputPort;
			port excitationInput : ExcitationInputPort;
			port differentialOutput : DifferentialOutputPort;
			
			part primaryCoil : PrimaryCoil {
				port excitationIn redefines excitationIn;
			}
			
			part rotor : RotorAssembly {
				port rotationalInput redefines rotationalInput;
			}
			
			part secondaryCoil1 : SecondaryCoilPair {
				attribute coilID = 1;
			}
			
			part secondaryCoil2 : SecondaryCoilPair {
				attribute coilID = 2;
			}
			
			part demodulator : DemodulatorCircuit;
			
			part calculator : AngleCalculator;
			
			connection excitationConnection connect 
				excitationInput to primaryCoil.excitationIn;
			
			connection mechanicalConnection connect 
				mechanicalInput to rotor.rotationalInput;
			
			connection coil1Connection connect 
				secondaryCoil1.inducedVoltage to demodulator.primarySignal;
			
			connection coil2Connection connect 
				secondaryCoil2.inducedVoltage to demodulator.secondarySignal;
			
			connection amplitudeConnection connect 
				demodulator.demodulatedAmplitude to calculator.amplitude;
			
			connection phaseConnection connect 
				demodulator.demodulatedPhase to calculator.phase;
			
			state machine RVDTOperation {
				state Idle {
					entry action { doc /* Initialize transducer components. */}
				}
				state Energized {
					entry action { doc /* Primary coil receives excitation. */}
				}
				state Measuring {
					entry action { doc /* Continuous angular position measurement. */}
				}
				state Fault {
					entry action { doc /* Error condition detected. */}
				}
				
				transition first Idle
					accept excitationApplied : ExcitationVoltage
					then Energized;
				
				transition first Energized
					if excitationInput.voltage > 0.0
					then Measuring;
				
				transition first Measuring
					if operatingTemperature > 398.15 or operatingTemperature < 218.15
					then Fault;
				
				transition first Fault
					accept systemReset
					then Idle;
				
				transition first Measuring
					accept excitationRemoved
					then Idle;
			}
		}
	}
	
	package Usages {
		import Definitions::*;
		
		action measureAngularPosition : MeasureAngularPosition {
			in shaftAngle : AngularPosition;
			in excitationVoltage : ExcitationVoltage;
			in excitationFrequency : CarrierFrequency;
			out measuredAngle : AngularPosition;
		}
		
		part rvdtSystem : RVDTTransducer {
			doc /* 
				Complete RVDT System for Precision Angular Position Measurement.
				
				Primary Function:
				The RVDT system provides contactless, high-precision measurement of rotational 
				shaft position by converting mechanical angular displacement into proportional 
				electrical signals. An AC excitation voltage energizes the primary coil, creating 
				a time-varying magnetic field. As the shaft rotates, the ferromagnetic rotor 
				modulates the magnetic coupling to two symmetrically positioned secondary coils. 
				This produces differential AC voltages whose amplitude and phase encode the 
				angular position. Advanced signal conditioning demodulates and processes these 
				voltages to compute the precise shaft angle with high linearity and resolution. 
				The non-contact electromagnetic principle ensures unlimited rotational life, 
				immunity to wear, and reliable operation in harsh environments including extreme 
				temperatures, vibration, and contamination. Applications include aerospace flight 
				control surfaces, industrial servo systems, robotic joints, and precision 
				instrumentation requiring absolute angular feedback.
			*/
			
			perform action measureAngularPosition[*] ordered;
			
			satisfy accuracyReq : AccuracyRequirement;
			satisfy rangeReq : OperationalRangeRequirement;
			satisfy tempReq : TemperatureStabilityRequirement;
			satisfy freqReq : ExcitationFrequencyRequirement;
		}
		
		requirement accuracyReq : AccuracyRequirement {
			subject rvdt = rvdtSystem;
		}
		
		requirement rangeReq : OperationalRangeRequirement {
			subject rvdt = rvdtSystem;
		}
		
		requirement tempReq : TemperatureStabilityRequirement {
			subject rvdt = rvdtSystem;
		}
		
		requirement freqReq : ExcitationFrequencyRequirement {
			subject rvdt = rvdtSystem;
		}
	}
}
