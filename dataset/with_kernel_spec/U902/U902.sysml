package 'SQUID Magnetometer System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def MagneticFlux;
		item def ElectricSignal;
		item def MeasurementData;

		port def MagneticFluxPort {
			out item flux : MagneticFlux;
		}
		port def ElectricSignalPort {
			out item signal : ElectricSignal;
		}
		port def BiasCurrentPort {
			out item biasCurrent : ElectricSignal;
		}
		port def DataPort {
			out item data : MeasurementData;
		}

		part def JosephsonJunction {
			doc /* Thin insulating barrier between superconductors allowing quantum tunneling of electron pairs. */
			port biasIn : ~BiasCurrentPort;
			port signalOut : ElectricSignalPort;
			attribute criticalCurrent : ElectricCurrent;
			attribute normalResistance : Real;
		}

		part def SuperconductingLoop {
			doc /* Superconducting loop interrupted by two Josephson junctions. */
			port fluxIn : ~MagneticFluxPort;
			port biasIn : ~BiasCurrentPort;
			port signalOut : ElectricSignalPort;
			attribute inductance : Real;
			part junction1 : JosephsonJunction;
			part junction2 : JosephsonJunction;

			flow of biasCurrent : ElectricSignal
				from biasIn.biasCurrent to junction1.biasIn.biasCurrent;
			flow of biasCurrent : ElectricSignal
				from biasIn.biasCurrent to junction2.biasIn.biasCurrent;
			flow of signal : ElectricSignal
				from junction1.signalOut.signal to signalOut.signal;
		}

		part def SQUIDSensor {
			doc /* Core SQUID sensor converting magnetic flux to a voltage signal. */
			port fluxIn : ~MagneticFluxPort;
			port biasIn : ~BiasCurrentPort;
			port signalOut : ElectricSignalPort;
			part squidLoop : SuperconductingLoop;

			flow of flux : MagneticFlux
				from fluxIn.flux to squidLoop.fluxIn.flux;
			flow of biasCurrent : ElectricSignal
				from biasIn.biasCurrent to squidLoop.biasIn.biasCurrent;
			flow of signal : ElectricSignal
				from squidLoop.signalOut.signal to signalOut.signal;
		}

		part def CryogenicSystem {
			doc /* Cryostat maintaining cryogenic temperatures for superconductivity. */
			attribute coolantTemperature : Temperature = 4.2 [K];
			attribute coolingCapacity : Real;
			perform action 'cool down' : CoolDown;
		}

		part def MagneticShield {
			doc /* Multi-layer high-permeability shield attenuating external magnetic noise. */
			attribute permeability : Real;
			attribute shieldingFactor : Real;
			attribute numLayers : Integer;
		}

		part def FluxTransformer {
			doc /* Superconducting pickup coil channeling external flux into the SQUID loop. */
			port fluxIn : ~MagneticFluxPort;
			port fluxOut : MagneticFluxPort;
			attribute turnsRatio : Real;
			attribute pickupCoilArea : Real;
		}

		part def BiasCurrentSource {
			doc /* Stable and precise current source biasing the Josephson junctions. */
			port biasOut : BiasCurrentPort;
			attribute biasCurrent : ElectricCurrent;
			perform action 'provide bias' : ProvideBias;
		}

		part def ReadoutElectronics {
			doc /* Amplifies, filters, and digitizes the SQUID voltage signal. */
			port signalInPort : ~ElectricSignalPort;
			port dataOutPort : DataPort;
			attribute gain : Real;
			attribute bandwidth : Real;
			attribute samplingRate : Real;
		}

		part def SQUIDMagnetometer {
			doc /* Complete SQUID magnetometer instrument system. */
			attribute operatingTemperature : Temperature = 4.2 [K];
			attribute maxTempThreshold : Temperature = 4.5 [K];
			perform action 'measure field' : MeasureField;
		}

		action def CoolDown {
			out temp : Temperature;
		}
		action def ProvideBias {
			out current : ElectricSignal;
		}
		action def Amplify {
			in signalIn : ElectricSignal;
			out signalOut : ElectricSignal;
		}
		action def FilterSignal {
			in signalIn : ElectricSignal;
			out signalOut : ElectricSignal;
		}
		action def Digitize {
			in signalIn : ElectricSignal;
			out dataOut : MeasurementData;
		}
		action def MeasureField;

		state def SQUIDOperationalStates;

		attribute def 'Start Cooldown';
		attribute def 'Stabilized';
		attribute def 'Bias Set';
		attribute def 'Fault Detected';
		attribute def 'Reset';
		attribute def 'Shutdown';

		requirement def SensitivityRequirement {
			doc /* The SQUID magnetometer must detect extremely weak magnetic fields,
			      thousands of times weaker than Earth's magnetic field. */
			attribute minDetectableField : MagneticFluxDensity;
			constraint { minDetectableField <= 50e-12 [T] }
		}

		requirement def CryogenicRequirement {
			doc /* The SQUID sensor must be maintained at approximately 4.2 K
			      for superconducting operation. */
			attribute maxOperatingTemp : Temperature;
			constraint { maxOperatingTemp <= 4.5 [K] }
		}
	}

	package Usages {
		private import Definitions::*;

		action 'cool down' : CoolDown;
		action 'provide bias' : ProvideBias;
		action 'measure field' : MeasureField;

		state operationalStates : SQUIDOperationalStates {
			in sys : SQUIDMagnetometer;
			in cryo : CryogenicSystem;

			entry; then Idle;
			state Idle;
			accept 'Start Cooldown'
				then Cooldown;
			state Cooldown {
				do 'cool down' { out temp; }
			}
			accept when 'cool down'.temp <= sys.operatingTemperature
				then Stabilizing;
			accept 'Fault Detected'
				then Fault;
			state Stabilizing;
			accept 'Stabilized'
				then Biasing;
			state Biasing {
				do 'provide bias';
			}
			accept 'Bias Set'
				then Measuring;
			state Measuring {
				do 'measure field';
			}
			accept 'Fault Detected'
				then Fault;
			accept 'Shutdown'
				then Idle;
			state Fault;
			accept 'Reset'
				then Idle;
		}

		part squidMagnetometer : SQUIDMagnetometer {
			port externalFluxIn : ~MagneticFluxPort;
			port dataOutPort : DataPort;

			part magneticShield : MagneticShield;
			part cryogenicSystem : CryogenicSystem;
			part fluxTransformer : FluxTransformer;
			part squidSensor : SQUIDSensor;
			part biasCurrentSource : BiasCurrentSource;
			part readoutElectronics : ReadoutElectronics {
				perform action amplify : Amplify {
					in signalIn = signalInPort.signal;
				}
				perform action filterSig : FilterSignal {
					in signalIn = amplify.signalOut;
				}
				perform action digitize : Digitize {
					in signalIn = filterSig.signalOut;
					out dataOut = dataOutPort.data;
				}
			}

			flow of flux : MagneticFlux
				from externalFluxIn.flux to fluxTransformer.fluxIn.flux;
			flow of flux : MagneticFlux
				from fluxTransformer.fluxOut.flux to squidSensor.fluxIn.flux;
			flow of biasCurrent : ElectricSignal
				from biasCurrentSource.biasOut.biasCurrent to squidSensor.biasIn.biasCurrent;
			flow of signal : ElectricSignal
				from squidSensor.signalOut.signal to readoutElectronics.signalInPort.signal;
			flow of data : MeasurementData
				from readoutElectronics.dataOutPort.data to dataOutPort.data;

			requirement sensitivityReq : SensitivityRequirement {
				attribute minDetectableField = 10e-15 [T];
			}
			requirement cryogenicReq : CryogenicRequirement {
				attribute maxOperatingTemp = 4.2 [K];
			}

			exhibit operationalStates {
				in sys = squidMagnetometer;
				in cryo = cryogenicSystem;
			}
		}
	}
}
