package 'FIA System' {
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ISQ::*;
		private import ScalarValues::*;

		/* ---- Item Definitions ---- */
		item def CarrierSolution;
		item def ReagentSolution;
		item def Sample {
			attribute sampleID : String;
		}
		item def SamplePlug {
			attribute volume : VolumeValue = 200 [microliter];
		}
		item def CarrierWithSample;
		item def MixedStream;
		item def ReactedStream {
			attribute colorIntensity : Real;
		}
		item def Waste;

		/* ---- Signal / Value Definitions ---- */
		attribute def AbsorbanceSignal {
			attribute value : Real;
			attribute wavelength : LengthValue = 540 [nanometer];
		}
		attribute def ConcentrationResult {
			attribute concentration : MassConcentrationValue;
			attribute sampleID : String;
		}
		attribute def InjectCommand;
		attribute def FillCommand;
		attribute def CalibrationCurve {
			attribute slope : Real;
			attribute intercept : Real;
		}

		/* ---- Port Definitions ---- */
		port def LiquidOutPort {
			out item liquid;
		}
		port def LiquidInPort {
			in item liquid;
		}
		port def LiquidInOutPort {
			in item liquidIn;
			out item liquidOut;
		}
		port def SignalOutPort {
			out item signal : AbsorbanceSignal;
		}
		port def SignalInPort {
			in item signal : AbsorbanceSignal;
		}
		port def ResultOutPort {
			out item result : ConcentrationResult;
		}
		port def CommandInPort {
			in item command;
		}

		/* ---- Part Definitions ---- */
		part def PeristalticPump {
			attribute flowRate : VolumeFlowRateValue;
			port liquidIn : ~LiquidOutPort;
			port liquidOut : LiquidOutPort;
			perform action pumpLiquid {
				in liquidIn;
				out liquidOut;
			}
		}

		part def InjectionValve {
			attribute sampleLoopVolume : VolumeValue = 200 [microliter];
			port sampleIn : ~LiquidOutPort;
			port carrierIn : ~LiquidOutPort;
			port carrierOut : LiquidOutPort;
			port commandPort : ~CommandInPort;
			perform action injectSample {
				in carrier = carrierIn.liquid;
				in sample = sampleIn.liquid;
				out injected = carrierOut.liquid;
			}
		}

		part def MixingTee {
			port inlet1 : ~LiquidOutPort;
			port inlet2 : ~LiquidOutPort;
			port outlet : LiquidOutPort;
			perform action mixStreams {
				in stream1;
				in stream2;
				out mixed;
			}
		}

		part def ReactionCoil {
			attribute length : LengthValue;
			attribute innerDiameter : LengthValue;
			attribute residenceTime : TimeValue;
			port inlet : ~LiquidOutPort;
			port outlet : LiquidOutPort;
			perform action react {
				in mixed;
				out reacted;
			}
		}

		part def OpticalDetector {
			attribute wavelength : LengthValue = 540 [nanometer];
			port liquidIn : ~LiquidOutPort;
			port liquidOut : LiquidOutPort;
			port signalOut : SignalOutPort;
			perform action measureAbsorbance {
				in liquid;
				out signal : AbsorbanceSignal;
			}
		}

		part def DataAcquisitionSystem {
			attribute calibration : CalibrationCurve;
			port signalIn : ~SignalInPort;
			port resultOut : ResultOutPort;
			perform action processData {
				in signal : AbsorbanceSignal;
				out result : ConcentrationResult;
			}
		}

		part def WasteReservoir {
			attribute capacity : VolumeValue;
			attribute currentVolume : VolumeValue;
			port liquidIn : ~LiquidOutPort;
		}

		part def SampleSource {
			port sampleOut : LiquidOutPort;
		}

		part def CarrierReservoir {
			port carrierOut : LiquidOutPort;
		}

		part def ReagentReservoir {
			port reagentOut : LiquidOutPort;
		}

		/* ---- Action Definitions ---- */
		action def PumpCarrier {
			in carrier;
			out pumpedCarrier;
		}
		action def PumpReagent {
			in reagent;
			out pumpedReagent;
		}
		action def FillSampleLoop {
			in sample;
			out filledLoop;
		}
		action def InjectIntoCarrier {
			in carrier;
			in samplePlug;
			out carrierWithSample;
		}
		action def MergeStreams {
			in carrierWithSample;
			in reagent;
			out mixedStream;
		}
		action def PerformReaction {
			in mixedStream;
			out reactedStream;
		}
		action def DetectAbsorbance {
			in reactedStream;
			out absorbanceSignal;
		}
		action def ComputeConcentration {
			in absorbanceSignal;
			out concentrationResult;
		}
		action def AnalyzeSample {
			in sample;
			out concentrationResult;
		}

		/* ---- Requirements ---- */
		requirement def AnalysisTimeRequirement {
			attribute maxAnalysisTime : TimeValue = 60 [second];
			subject theSystem;
			text = "Each full analysis cycle shall complete in under one minute.";
		}
		requirement def SampleVolumeRequirement {
			attribute maxSampleVolume : VolumeValue = 200 [microliter];
			subject theSystem;
			text = "The system shall consume no more than 200 microliters per analysis.";
		}
		requirement def DetectionAccuracyRequirement {
			attribute minWavelength : LengthValue = 540 [nanometer];
			subject theDetector;
			text = "The detector shall measure absorbance at 540 nm for the colored product.";
		}
	}

	package Usages {
		part fiaSystem {
			attribute analysisTime : TimeValue = 45 [second];
			attribute sampleVolume : VolumeValue = 200 [microliter];

			/* Reservoirs */
			part carrierReservoir : CarrierReservoir;
			part reagentReservoir : ReagentReservoir;
			part sampleSource : SampleSource;

			/* Pumps */
			part carrierPump : PeristalticPump {
				attribute flowRate : VolumeFlowRateValue = 2.0 [milliliter / minute];
			}
			part reagentPump : PeristalticPump {
				attribute flowRate : VolumeFlowRateValue = 1.0 [milliliter / minute];
			}

			/* Injection Valve */
			part injectionValve : InjectionValve {
				attribute sampleLoopVolume : VolumeValue = 200 [microliter];
			}

			/* Mixing Tee */
			part mixingTee : MixingTee;

			/* Reaction Coil */
			part reactionCoil : ReactionCoil {
				attribute length : LengthValue = 100 [centimeter];
				attribute innerDiameter : LengthValue = 0.8 [millimeter];
				attribute residenceTime : TimeValue = 30 [second];
			}

			/* Detector */
			part detector : OpticalDetector {
				attribute wavelength : LengthValue = 540 [nanometer];
			}

			/* Data Acquisition */
			part dataAcquisition : DataAcquisitionSystem {
				attribute calibration : CalibrationCurve {
					attribute slope : Real = 0.045;
					attribute intercept : Real = 0.002;
				}
			}

			/* Waste */
			part wasteReservoir : WasteReservoir {
				attribute capacity : VolumeValue = 2000 [milliliter];
				attribute currentVolume : VolumeValue = 0 [milliliter];
			}

			/* ---- Connections / Flows ---- */
			flow of carrier : CarrierSolution
				from carrierReservoir.carrierOut.liquid to carrierPump.liquidIn.liquid;

			flow of reagent : ReagentSolution
				from reagentReservoir.reagentOut.liquid to reagentPump.liquidIn.liquid;

			flow of sample : Sample
				from sampleSource.sampleOut.liquid to injectionValve.sampleIn.liquid;

			flow of carrier : CarrierSolution
				from carrierPump.liquidOut.liquid to injectionValve.carrierIn.liquid;

			flow of reagent : ReagentSolution
				from reagentPump.liquidOut.liquid to mixingTee.inlet2.liquid;

			flow of carrierWithSample : CarrierWithSample
				from injectionValve.carrierOut.liquid to mixingTee.inlet1.liquid;

			flow of mixedStream : MixedStream
				from mixingTee.outlet.liquid to reactionCoil.inlet.liquid;

			flow of reactedStream : ReactedStream
				from reactionCoil.outlet.liquid to detector.liquidIn.liquid;

			flow of waste : Waste
				from detector.liquidOut.liquid to wasteReservoir.liquidIn.liquid;

			flow of signal : AbsorbanceSignal
				from detector.signalOut.signal to dataAcquisition.signalIn.signal;

			/* ---- Analysis Behavior ---- */
			perform action analyzeSample : AnalyzeSample {
				in sample;
				out concentrationResult;

				action pumpCarrier : PumpCarrier {
					in carrier = carrierReservoir.carrierOut.liquid;
					out pumpedCarrier;
				}
				flow pumpCarrier.pumpedCarrier to injectIntoCarrier.carrier;

				action pumpReagent : PumpReagent {
					in reagent = reagentReservoir.reagentOut.liquid;
					out pumpedReagent;
				}
				flow pumpReagent.pumpedReagent to mergeStreams.reagent;

				action fillSampleLoop : FillSampleLoop {
					in sample = sampleSource.sampleOut.liquid;
					out filledLoop;
				}
				flow fillSampleLoop.filledLoop to injectIntoCarrier.samplePlug;

				action injectIntoCarrier : InjectIntoCarrier {
					in carrier;
					in samplePlug;
					out carrierWithSample;
				}
				flow injectIntoCarrier.carrierWithSample to mergeStreams.carrierWithSample;

				action mergeStreams : MergeStreams {
					in carrierWithSample;
					in reagent;
					out mixedStream;
				}
				flow mergeStreams.mixedStream to performReaction.mixedStream;

				action performReaction : PerformReaction {
					in mixedStream;
					out reactedStream;
				}
				flow performReaction.reactedStream to detectAbsorbance.reactedStream;

				action detectAbsorbance : DetectAbsorbance {
					in reactedStream;
					out absorbanceSignal;
				}
				flow detectAbsorbance.absorbanceSignal to computeConcentration.absorbanceSignal;

				action computeConcentration : ComputeConcentration {
					in absorbanceSignal;
					out concentrationResult;
				}
			}

			/* ---- Requirements Satisfaction ---- */
			satisfy analysisTimeReq : AnalysisTimeRequirement {
				theSystem = fiaSystem;
			}
			satisfy sampleVolumeReq : SampleVolumeRequirement {
				theSystem = fiaSystem;
			}
			satisfy detectionAccuracyReq : DetectionAccuracyRequirement {
				theDetector = detector;
			}
		}
	}
}
