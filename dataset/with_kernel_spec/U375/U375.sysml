package 'Schiøtz Tonometer' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SI::*;
	
	part def HousingFrame;
	
	port def EyeContact;
	port def LeverConnection;
	port def ScaleConnection;
	port def WeightConnection;
	
	part def Footplate {
		port corneaContactPort : EyeContact;
	}
	
	part def Plunger {
		attribute displacement : LengthValue;
		port leverConnectionPort : LeverConnection;
		port weightAttachmentPort : WeightConnection;
	}
	
	part def InterchangeableWeight {
		attribute mass : MassValue;
		port weightPort : WeightConnection;
	}
	
	part def LeverMechanism {
		attribute amplificationFactor : Real = 10.0;
		port inputPort : LeverConnection;
		port outputPort : ScaleConnection;
	}
	
	part def CalibratedScale {
		attribute reading : Real;
		port pointerPort : ScaleConnection;
	}
	
	part def SchiotzTonometer {
		part housingFrame : HousingFrame;
		part footplate : Footplate;
		part plunger : Plunger;
		part leverMechanism : LeverMechanism;
		part calibratedScale : CalibratedScale;
		part appliedWeight : InterchangeableWeight;
		
		port eyeContactPort : EyeContact;
		
		connect plunger.leverConnectionPort to leverMechanism.inputPort;
		connect leverMechanism.outputPort to calibratedScale.pointerPort;
		connect appliedWeight.weightPort to plunger.weightAttachmentPort;
		
		state TonometerStates {
			state idle;
			state positioning;
			state measuring;
			state reading;
			
			first idle then positioning;
			first positioning then measuring;
			first measuring then reading;
			first reading then idle;
		}
	}
	
	item def IOPMeasurement {
		attribute iop : PressureValue;
		attribute scaleReading : Real;
		attribute appliedMass : MassValue;
	}
	
	action def MeasureIOP {
		in mass : MassValue;
		out scaleReading : Real;
	}
	
	action def LookupIOP {
		in scaleReading : Real;
		in mass : MassValue;
		out iop : PressureValue;
	}
	
	calc def IOPConversion {
		in scaleReading : Real;
		in mass : MassValue;
		return iop : PressureValue;
		doc /* Standard conversion table for Schiøtz tonometer. */
	}
	
	requirement def TonometerMeasurementRequirement {
		doc /* The tonometer shall measure intraocular pressure using indentation. */
		subject tonometer : SchiotzTonometer;
	}
	
	part weight5_5 : InterchangeableWeight { attribute mass = 5.5 [g]; }
	part weight7_5 : InterchangeableWeight { attribute mass = 7.5 [g]; }
	part weight10_0 : InterchangeableWeight { attribute mass = 10.0 [g]; }
	
	part tonometer : SchiotzTonometer {
		perform action measureIOP : MeasureIOP {
			in mass = appliedWeight.mass;
		}
		perform action lookupIOP : LookupIOP {
			in scaleReading = measureIOP.scaleReading;
			in mass = appliedWeight.mass;
		}
	}
}
