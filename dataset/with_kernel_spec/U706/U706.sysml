package HeartbeatSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	public import Definitions::*;

	package Definitions {
		item def RawPulseSignal {
			attribute amplitude: Real;
			attribute timestamp: Real;
		}

		item def CleanSignal {
			attribute amplitude: Real;
			attribute timestamp: Real;
		}

		item def HeartRateMeasurement {
			attribute bpm: Real;
			attribute isValid: Boolean;
			attribute signalStrength: Real;
			attribute timestamp: Real;
		}

		attribute def PowerOnSignal;
		attribute def MeasureCommand;
		attribute def FaultSignal;
		attribute def ResetSignal;

		port def MeasurementPort {
			out item measurement: HeartRateMeasurement;
		}

		action def DetectPulse {
			out item rawSignal: RawPulseSignal;
		}

		action def FilterNoise {
			in item rawSignal: RawPulseSignal;
			out item cleanSignal: CleanSignal;
		}

		action def IdentifyHeartbeats {
			in item cleanSignal: CleanSignal;
			out heartbeatCount: Integer;
		}

		action def CalculateBPM {
			in heartbeatCount: Integer;
			out bpm: Real;
		}

		action def EvaluateSignalQuality {
			in item cleanSignal: CleanSignal;
			out isValid: Boolean;
			out signalStrength: Real;
		}

		action def ProcessSignal {
			in item rawSignal: RawPulseSignal;
			out item measurement: HeartRateMeasurement;
		}

		action def TransmitData {
			in item measurement: HeartRateMeasurement;
		}

		action def Initialize;

		part def PPGSensor {
			attribute greenLightWavelength: Real = 530;
			out item rawSignal: RawPulseSignal;
			perform action detectPulse: DetectPulse;
		}

		part def SignalProcessor {
			in item rawSignal: RawPulseSignal;
			out item measurement: HeartRateMeasurement;
			perform action processSignal: ProcessSignal;
		}

		part def DataBuffer {
			in item measurement: HeartRateMeasurement;
			item bufferedMeasurements: HeartRateMeasurement[0..*];
		}

		part def HeartbeatSensingUnit {
			out port measurementOut: MeasurementPort;
			part ppgSensor: PPGSensor;
			part signalProcessor: SignalProcessor;
			part dataBuffer: DataBuffer;
			exhibit state hsuStates: HsuStates;
		}

		state def HsuStates;

		requirement def HeartRateRangeRequirement {
			doc /* The unit shall measure heart rates between 40 and 200 BPM. */
			attribute minBPM: Real = 40;
			attribute maxBPM: Real = 200;
		}

		requirement def AccuracyRequirement {
			doc /* The unit shall measure heart rate with an accuracy of ±2 BPM. */
			attribute maxError: Real = 2;
		}

		requirement def UpdateTimeRequirement {
			doc /* The unit shall provide an updated reading within two seconds. */
			attribute maxUpdateTime: Real = 2;
		}
	}

	package Usages {
		private import Definitions::*;

		action 'process signal': ProcessSignal {
			in item rawSignal: RawPulseSignal;
			out item measurement: HeartRateMeasurement;

			action 'filter noise': FilterNoise {
				in item rawSignal = 'process signal'::rawSignal;
				out item cleanSignal: CleanSignal;
			}
			flow 'filter noise'.cleanSignal to 'identify heartbeats'.cleanSignal;
			flow 'filter noise'.cleanSignal to 'evaluate signal quality'.cleanSignal;

			action 'identify heartbeats': IdentifyHeartbeats {
				in item cleanSignal: CleanSignal;
				out heartbeatCount: Integer;
			}
			flow 'identify heartbeats'.heartbeatCount to 'calculate bpm'.heartbeatCount;

			action 'calculate bpm': CalculateBPM {
				in heartbeatCount: Integer;
				out bpm: Real;
			}

			action 'evaluate signal quality': EvaluateSignalQuality {
				in item cleanSignal: CleanSignal;
				out isValid: Boolean;
				out signalStrength: Real;
			}
		}

		part hsu : HeartbeatSensingUnit {
			out port measurementOut: MeasurementPort;

			part ppgSensor: PPGSensor {
				out item rawSignal: RawPulseSignal;
			}

			flow ppgSensor.rawSignal to signalProcessor.rawSignal;

			part signalProcessor: SignalProcessor {
				in item rawSignal: RawPulseSignal;
				out item measurement: HeartRateMeasurement;
			}

			flow signalProcessor.measurement to dataBuffer.measurement;
			flow signalProcessor.measurement to measurementOut.measurement;

			part dataBuffer: DataBuffer {
				in item measurement: HeartRateMeasurement;
				item bufferedMeasurements: HeartRateMeasurement[0..*];
			}

			state hsuStates: HsuStates {
				entry; then off;

				state off;
				accept PowerOnSignal then initializing;

				state initializing {
					entry action init: Initialize;
				}
				transition init_complete first initializing then ready;

				state ready;
				accept MeasureCommand then measuring;

				state measuring {
					do action 'process signal': ProcessSignal {
						in item rawSignal = ppgSensor.rawSignal;
						out item measurement = signalProcessor.measurement;
					}
				}
				transition measure_complete first measuring then transmitting;

				state transmitting {
					entry action transmit: TransmitData {
						in item measurement = signalProcessor.measurement;
					}
				}
				transition transmit_complete first transmitting then ready;

				state fault;
				accept FaultSignal then fault;
				accept ResetSignal then off;
			}
		}

		requirement heartRateRange: HeartRateRangeRequirement;
		requirement accuracy: AccuracyRequirement;
		requirement updateTime: UpdateTimeRequirement;
	}
}
