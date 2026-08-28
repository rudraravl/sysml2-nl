package 'McLeod Gauge System' {
	private import ScalarValues::Real;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		item def Gas;
		item def Mercury {
			attribute purity : Real;
		}
		item def StartMeasurement;

		port def GasPort {
			in item gas : Gas;
		}

		port def MercuryPort {
			out item mercury : Mercury;
		}

		part def Bulb {
			port gasInPort : GasPort;
			port gasOutPort : ~GasPort;
			port mercuryInPort : ~MercuryPort;
			attribute volume : Volume;
			item gas : Gas;
		}

		part def Capillary {
			port gasInPort : GasPort;
			attribute crossSectionArea : Area;
			attribute length : Length;
			attribute measuredHeight : Length;
			item gas : Gas;
		}

		part def MercuryReservoir {
			port mercuryOutPort : MercuryPort;
			item mercury : Mercury;
			attribute level : Length;
		}

		part def Scale {
			attribute reading : Length;
		}

		action def FillBulb {
			in gasIn : Gas;
			out trappedGas : Gas;
		}

		action def RaiseMercury {
			in mercury : Mercury;
			out raisedMercury : Mercury;
		}

		action def CompressGas {
			in trappedGas : Gas;
			in mercury : Mercury;
			out compressedGas : Gas;
			out columnHeight : Length;
		}

		action def MeasureHeight {
			in height : Length;
			out measuredHeight : Length;
		}

		action def CalculatePressure {
			in height : Length;
			in bulbVolume : Volume;
			in capillaryArea : Area;
			in mercuryDensity : MassDensity;
			in gravity : Acceleration;
			out originalPressure : Pressure;
		}

		action def LowerMercury {
			in mercury : Mercury;
			out loweredMercury : Mercury;
		}

		action def MeasurementCycle {
			in gasSample : Gas;
			out calculatedPressure : Pressure;

			action fillBulb : FillBulb {
				in gasIn = gasSample;
				out trappedGas;
			}
			flow from fillBulb.trappedGas to compressGas.trappedGas;

			action raiseMercury : RaiseMercury {
				in mercury;
				out raisedMercury;
			}
			flow from raiseMercury.raisedMercury to compressGas.mercury;

			action compressGas : CompressGas {
				in trappedGas;
				in mercury;
				out compressedGas;
				out columnHeight;
			}
			flow from compressGas.columnHeight to measureHeight.height;

			action measureHeight : MeasureHeight {
				in height;
				out measuredHeight;
			}
			flow from measureHeight.measuredHeight to calculatePressure.height;

			action calculatePressure : CalculatePressure {
				in height;
				in bulbVolume;
				in capillaryArea;
				in mercuryDensity;
				in gravity;
				out originalPressure = calculatedPressure;
			}

			action lowerMercury : LowerMercury {
				in mercury;
				out loweredMercury;
			}
		}

		part def McLeodGauge {
			port vacuumPort : GasPort;
			part bulb : Bulb;
			part capillary : Capillary;
			part reservoir : MercuryReservoir;
			part scale : Scale;

			attribute mercuryDensity : MassDensity = 13534;
			attribute gravity : Acceleration = 9.81;
			attribute originalPressure : Pressure;

			perform action measureCycle : MeasurementCycle {
				in gasSample = vacuumPort.gas;
				out calculatedPressure = originalPressure;
			}
		}

		state def GaugeOperationalState {
			entry; then idle;
			state idle;
			transition first idle accept StartMeasurement then filling;
			state filling;
			transition first filling then raising;
			state raising;
			transition first raising then compressing;
			state compressing;
			transition first compressing then measuring;
			state measuring;
			transition first measuring then calculating;
			state calculating;
			transition first calculating then lowering;
			state lowering;
			transition first lowering then idle;
		}

		requirement def AccuracyRequirement {
			text "The system shall provide highly accurate vacuum pressure measurements.";
			attribute requiredAccuracy : Real;
			subject gauge : McLeodGauge;
		}

		requirement def OperatingRangeRequirement {
			text "The gauge shall operate within a pressure range of 0.001 to 100 Pascals.";
			attribute minPressure : Pressure;
			attribute maxPressure : Pressure;
			subject gauge : McLeodGauge;
		}

		requirement def MercuryPurityRequirement {
			text "The gauge shall rely on high-purity mercury for precision.";
			attribute minPurity : Real;
			subject mercury : Mercury;
		}
	}

	package Usages {
		part context {
			part vacuumSystem {
				port gasPort : GasPort;
				item gas : Gas;
			}

			part gauge : McLeodGauge {
				part bulb : Bulb {
					:>> volume = 0.5;
				}
				part capillary : Capillary {
					:>> crossSectionArea = 1e-6;
					:>> length = 0.2;
				}
				part reservoir : MercuryReservoir {
					item mercury : Mercury {
						:>> purity = 0.99999;
					}
				}

				exhibit state operational : GaugeOperationalState;

				flow from vacuumPort.gas to bulb.gasInPort.gas;
				flow from bulb.gasOutPort.gas to capillary.gasInPort.gas;
				flow from reservoir.mercuryOutPort.mercury to bulb.mercuryInPort.mercury;
			}

			flow of gas : Gas
				from vacuumSystem.gasPort.gas to gauge.vacuumPort.gas;

			requirement accuracyReq : AccuracyRequirement {
				:>> requiredAccuracy = 0.01;
				:>> subject = gauge;
			}
			requirement rangeReq : OperatingRangeRequirement {
				:>> minPressure = 0.001 [SI::Pa];
				:>> maxPressure = 100 [SI::Pa];
				:>> subject = gauge;
			}
			requirement purityReq : MercuryPurityRequirement {
				:>> minPurity = 0.99999;
				:>> subject = gauge.reservoir.mercury;
			}
		}
	}
}
