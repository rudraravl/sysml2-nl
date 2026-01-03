package 'McLeod Gauge System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VacuumPressureValue :> PressureValue;
	attribute def MercuryHeightValue :> LengthValue;
	attribute def CompressionRatio :> Real;
	attribute def BulbVolumeValue :> VolumeValue;
	attribute def CapillaryVolumeValue :> VolumeValue;
	
	item def MercuryFluid {
		attribute density : MassDensityValue;
		attribute purity : Real;
	}
	
	item def GasSample {
		attribute initialPressure : VacuumPressureValue;
		attribute compressedPressure : PressureValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	port def VacuumPort {
		attribute pressure : VacuumPressureValue;
	}
	
	port def MercurySupplyPort {
		in item mercury : MercuryFluid;
	}
	
	port def MeasurementOutputPort {
		out pressureReading : VacuumPressureValue;
	}
	
	part def GlassBulb {
		attribute volume : BulbVolumeValue;
		attribute diameter : LengthValue;
		port vacuumConnection : VacuumPort;
	}
	
	part def CapillaryTube {
		attribute length : LengthValue;
		attribute innerDiameter : LengthValue;
		attribute volume : CapillaryVolumeValue;
		attribute calibratedScale : LengthValue[*];
	}
	
	part def MercuryReservoir {
		attribute capacity : VolumeValue;
		port mercurySupply : MercurySupplyPort;
		part storedMercury : MercuryFluid;
	}
	
	part def HeightMeasurementScale {
		attribute graduations : LengthValue[*];
		attribute resolution : LengthValue;
	}
	
	action def IsolateGasSample {
		in vacuumPort : VacuumPort;
		out isolatedGas : GasSample;
	}
	
	action def RaiseMercuryLevel {
		in reservoir : MercuryReservoir;
		out mercuryColumnHeight : MercuryHeightValue;
	}
	
	action def CompressGasSample {
		in gas : GasSample;
		in bulbVolume : BulbVolumeValue;
		in capillaryVolume : CapillaryVolumeValue;
		out compressionRatio : CompressionRatio;
		out compressedGas : GasSample;
	}
	
	action def MeasureMercuryColumnHeight {
		in scale : HeightMeasurementScale;
		out heightReading : MercuryHeightValue;
	}
	
	action def CalculateVacuumPressure {
		in mercuryHeight : MercuryHeightValue;
		in compressionRatio : CompressionRatio;
		in mercuryDensity : MassDensityValue;
		out vacuumPressure : VacuumPressureValue;
	}
	
	action def LowerMercuryLevel {
		in reservoir : MercuryReservoir;
	}
	
	action def PerformPressureMeasurement {
		in bulbVolume : BulbVolumeValue;
		in capillaryVolume : CapillaryVolumeValue;
		in mercuryDensity : MassDensityValue;
		out pressureReading : VacuumPressureValue;
		
		first start;
		then action isolate : IsolateGasSample;
		then action raise : RaiseMercuryLevel;
		then action compress : CompressGasSample {
			in gas = isolate.isolatedGas;
			in bulbVolume = PerformPressureMeasurement::bulbVolume;
			in capillaryVolume = PerformPressureMeasurement::capillaryVolume;
		}
		then action measure : MeasureMercuryColumnHeight;
		then action calculate : CalculateVacuumPressure {
			in mercuryHeight = measure.heightReading;
			in compressionRatio = compress.compressionRatio;
			in mercuryDensity = PerformPressureMeasurement::mercuryDensity;
		}
		then assign pressureReading := calculate.vacuumPressure;
		then action lower : LowerMercuryLevel;
		then done;
	}
	
	state def McLeodGaugeOperationalStates {
		entry; then idle;
		
		state idle;
		
		accept MeasurementRequest;
		then isolating;
		
		state isolating {
			do action IsolateGasSample;
		}
		then compressing;
		
		state compressing {
			do action CompressGasSample;
		}
		then measuring;
		
		state measuring {
			do action MeasureMercuryColumnHeight;
		}
		then calculating;
		
		state calculating {
			do action CalculateVacuumPressure;
		}
		then resetting;
		
		state resetting {
			do action LowerMercuryLevel;
		}
		then idle;
	}
	
	part def McLeodGauge {
		attribute operatingRange : VacuumPressureValue[2];
		attribute accuracy : Real;
		
		port vacuumInput : VacuumPort;
		port measurementOutput : MeasurementOutputPort;
		
		part bulb : GlassBulb {
			attribute :>> volume = 1000.0 [SI::mm3];
		}
		
		part capillaryTube : CapillaryTube {
			attribute :>> length = 200.0 [SI::mm];
			attribute :>> innerDiameter = 1.0 [SI::mm];
		}
		
		part reservoir : MercuryReservoir {
			part :>> storedMercury {
				attribute :>> density = 13534.0 [SI::kg/SI::m3];
				attribute :>> purity = 0.9999;
			}
		}
		
		part measurementScale : HeightMeasurementScale {
			attribute :>> resolution = 0.1 [SI::mm];
		}
		
		perform action measurePressure : PerformPressureMeasurement {
			in bulbVolume = bulb.volume;
			in capillaryVolume = capillaryTube.volume;
			in mercuryDensity = reservoir.storedMercury.density;
			out pressureReading;
		}
		
		exhibit state gaugeOperation : McLeodGaugeOperationalStates;
		
		connection bulbToVacuum connect bulb.vacuumConnection to vacuumInput;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The McLeod gauge shall measure vacuum pressure with accuracy 
		       better than 5% of the reading across its operating range. */
		
		subject gauge : McLeodGauge;
		
		require constraint {
			gauge.accuracy <= 0.05
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The McLeod gauge shall operate effectively in the pressure range 
		       from 0.001 Pa to 100 Pa. */
		
		subject gauge : McLeodGauge;
		
		require constraint {
			gauge.operatingRange[1] >= 0.001 [SI::Pa] and
			gauge.operatingRange[2] <= 100.0 [SI::Pa]
		}
	}
	
	requirement def MercuryPurityRequirement {
		doc /* The mercury used in the gauge shall have purity of at least 99.9% 
		       to ensure accurate measurements. */
		
		subject mercury : MercuryFluid;
		
		require constraint {
			mercury.purity >= 0.999
		}
	}
	
	requirement <'MCLEOD-001'> mcLeodGaugeSystemRequirement {
		doc /* The McLeod gauge system shall measure low vacuum pressures by 
		       compressing a known volume of gas and measuring the resulting 
		       pressure using a mercury column height measurement. */
		
		subject mcLeodSystem : McLeodGauge;
		
		require measurementAccuracy : MeasurementAccuracyRequirement;
		require operatingRange : OperatingRangeRequirement;
		require mercuryPurity : MercuryPurityRequirement;
	}
	
	part mcLeodGaugeSystem : McLeodGauge {
		attribute :>> operatingRange = (0.001 [SI::Pa], 100.0 [SI::Pa]);
		attribute :>> accuracy = 0.03;
		
		satisfy mcLeodGaugeSystemRequirement by mcLeodGaugeSystem;
	}
}
