package 'Bimetallic Strip System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ThermalExpansionCoefficient :> Real;
	
	part def Metal {
		attribute thermalExpansionCoeff : ThermalExpansionCoefficient;
		attribute thickness : LengthValue;
		attribute youngsModulus : PressureValue;
	}
	
	part def HighExpansionMetal :> Metal {
		attribute :>> thermalExpansionCoeff : ThermalExpansionCoefficient = 19.0e-6;
	}
	
	part def LowExpansionMetal :> Metal {
		attribute :>> thermalExpansionCoeff : ThermalExpansionCoefficient = 1.2e-6;
	}
	
	item def ThermalEnergy;
	item def MechanicalDisplacement;
	
	port def ThermalPort {
		in temperature : TemperatureValue;
	}
	
	port def MechanicalPort {
		out displacement : LengthValue;
		out bendingAngle : ISQ::AngleAndSolidAngleValue;
	}
	
	part def BimetallicStrip {
		doc /* A composite strip of two metals with different thermal expansion 
		       coefficients bonded together. */
		
		attribute stripLength : LengthValue;
		attribute stripWidth : LengthValue;
		attribute referenceTemperature : TemperatureValue;
		
		part highExpansionLayer : HighExpansionMetal {
			attribute :>> thickness : LengthValue = 0.5 [SI::mm];
		}
		
		part lowExpansionLayer : LowExpansionMetal {
			attribute :>> thickness : LengthValue = 0.5 [SI::mm];
		}
		
		in port thermalInput : ThermalPort;
		out port mechanicalOutput : MechanicalPort;
	}
	
	part def ElectricalContact {
		attribute contactGap : LengthValue;
		attribute contactResistance : ResistanceValue;
		
		in port mechanicalInput {
			in displacement : LengthValue;
		}
		
		out port electricalOutput {
			out isClosed : Boolean;
			out current : ElectricCurrentValue;
		}
	}
	
	part def TemperatureControlledSwitch {
		doc /* A switch that opens or closes based on ambient temperature using 
		       a bimetallic strip as the sensing and actuating element. */
		
		attribute setpointTemperature : TemperatureValue;
		attribute hysteresis : TemperatureValue;
		
		part strip : BimetallicStrip {
			attribute :>> stripLength : LengthValue = 50.0 [SI::mm];
			attribute :>> stripWidth : LengthValue = 10.0 [SI::mm];
			attribute :>> referenceTemperature : TemperatureValue = 293.15 [SI::K];
		}
		
		part fixedContact : ElectricalContact {
			attribute :>> contactGap : LengthValue = 0.5 [SI::mm];
		}
		
		part movableContact : ElectricalContact;
		
		in port temperatureSensor : ThermalPort;
		out port switchOutput {
			out switchState : Boolean;
			out outputCurrent : ElectricCurrentValue;
		}
		
		connection thermalCoupling connect temperatureSensor to strip.thermalInput;
		connection mechanicalCoupling connect strip.mechanicalOutput to fixedContact.mechanicalInput;
	}
	
	action def SenseTemperature {
		in currentTemperature : TemperatureValue;
		in referenceTemperature : TemperatureValue;
		out temperatureDelta : TemperatureValue;
	}
	
	action def CalculateThermalStrain {
		in temperatureDelta : TemperatureValue;
		in expansionCoeff1 : ThermalExpansionCoefficient;
		in expansionCoeff2 : ThermalExpansionCoefficient;
		out differentialStrain : Real;
	}
	
	action def ComputeBending {
		in differentialStrain : Real;
		in stripLength : LengthValue;
		in totalThickness : LengthValue;
		out bendingRadius : LengthValue;
		out tipDisplacement : LengthValue;
		out bendingAngle : ISQ::AngleAndSolidAngleValue;
	}
	
	action def ActuateContact {
		in tipDisplacement : LengthValue;
		in contactGap : LengthValue;
		out contactClosed : Boolean;
	}
	
	action def OperateThermalSwitch {
		in ambientTemperature : TemperatureValue;
		in setpoint : TemperatureValue;
		in stripLength : LengthValue;
		in totalThickness : LengthValue;
		in contactGap : LengthValue;
		in highExpansionCoeff : ThermalExpansionCoefficient;
		in lowExpansionCoeff : ThermalExpansionCoefficient;
		out switchClosed : Boolean;
		
		first start;
		then merge continuousControl;
		
		then action senseTemp : SenseTemperature {
			in currentTemperature = ambientTemperature;
			in referenceTemperature = setpoint;
			out temperatureDelta;
		}
		
		then action calculateStrain : CalculateThermalStrain {
			in temperatureDelta = senseTemp.temperatureDelta;
			in expansionCoeff1 = highExpansionCoeff;
			in expansionCoeff2 = lowExpansionCoeff;
			out differentialStrain;
		}
		
		then action computeBend : ComputeBending {
			in differentialStrain = calculateStrain.differentialStrain;
			in stripLength = stripLength;
			in totalThickness = totalThickness;
			out bendingRadius;
			out tipDisplacement;
			out bendingAngle;
		}
		
		then action actuate : ActuateContact {
			in tipDisplacement = computeBend.tipDisplacement;
			in contactGap = contactGap;
			out contactClosed;
		}
		
		then assign switchClosed := actuate.contactClosed;
		then continuousControl;
	}
	
	part bimetallicThermostat : TemperatureControlledSwitch {
		attribute :>> setpointTemperature : TemperatureValue = 295.15 [SI::K];
		attribute :>> hysteresis : TemperatureValue = 2.0 [SI::K];
		
		perform action switchOperation : OperateThermalSwitch {
			in ambientTemperature : TemperatureValue;
			in setpoint = setpointTemperature;
			in stripLength = strip.stripLength;
			in totalThickness = strip.highExpansionLayer.thickness + strip.lowExpansionLayer.thickness;
			in contactGap = fixedContact.contactGap;
			in highExpansionCoeff = strip.highExpansionLayer.thermalExpansionCoeff;
			in lowExpansionCoeff = strip.lowExpansionLayer.thermalExpansionCoeff;
			out switchClosed : Boolean;
		}
	}
	
	requirement def ThermalToMechanicalConversion {
		doc /* The bimetallic strip system shall convert thermal energy into 
		       mechanical displacement through differential thermal expansion. */
		
		subject strip : BimetallicStrip;
		
		require constraint temperatureResponse {
			doc /* The strip shall produce measurable bending when subjected to 
			       temperature changes. */
		}
		
		require constraint reversibility {
			doc /* The strip shall return to its original shape when temperature 
			       returns to reference value. */
		}
	}
	
	requirement def TemperatureSwitchingFunction {
		doc /* The system shall actuate electrical contacts based on temperature 
		       threshold crossing. */
		
		subject thermostat : TemperatureControlledSwitch;
		
		require constraint accuracyRequirement {
			thermostat.hysteresis <= 3.0 [SI::K]
		}
		
		require constraint repeatability {
			doc /* The switch shall operate consistently over multiple thermal cycles. */
		}
	}
	
	requirement <'BIMET-SYS-001'> bimetallicStripSystemRequirement {
		doc /* 
		The bimetallic strip system shall provide temperature-based mechanical 
		actuation for control applications. The system operates by exploiting 
		the differential thermal expansion between two bonded metal layers to 
		produce predictable bending displacement proportional to temperature change.
		This displacement is used to actuate electrical contacts, enabling 
		temperature-controlled switching without external power or electronics.
		Primary applications include thermostats, circuit breakers, and thermal 
		compensation devices.
		*/
		
		require thermalToMechanicalConversion;
		require temperatureSwitchingFunction;
	}
}
