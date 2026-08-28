package PiezoelectricSensingUnit {
	private import ISQ::*;
	private import ScalarValues::*;
	
	package Definitions {
		attribute def PZT_5H;
		attribute def FaultSignal;
		attribute def ResetSignal;
		
		item def Charge {
			attribute value : ElectricChargeValue;
		}
		
		item def AnalogVoltage {
			attribute value : VoltageValue;
		}
		
		item def DigitalReading {
			attribute rawValue : Integer;
			attribute pressure : PressureValue;
			attribute timestamp : TimeValue;
		}
		
		port def MechanicalPort {
			in force : ForceValue;
		}
		
		port def ChargeOutPort {
			out charge : Charge;
		}
		
		port def ChargeInPort {
			in charge : Charge;
		}
		
		port def VoltageOutPort {
			out voltage : AnalogVoltage;
		}
		
		port def VoltageInPort {
			in voltage : AnalogVoltage;
		}
		
		port def DigitalPort {
			out reading : DigitalReading;
		}
		
		port def PowerPort {
			in power : VoltageValue;
		}
		
		part def PiezoelectricSensor {
			attribute crystalMaterial : PZT_5H;
			port mechIn : MechanicalPort;
			port chargeOut : ChargeOutPort;
			action def Sense {
				in f : ForceValue;
				out q : Charge;
			}
			perform action sense : Sense {
				in f = mechIn.force;
				out q = chargeOut.charge;
			}
		}
		
		part def ChargeAmplifier {
			port powerIn : PowerPort;
			port chargeIn : ChargeInPort;
			port voltageOut : VoltageOutPort;
			action def Amplify {
				in q : Charge;
				in vcc : VoltageValue;
				out v : AnalogVoltage;
			}
			perform action amplify : Amplify {
				in q = chargeIn.charge;
				in vcc = powerIn.power;
				out v = voltageOut.voltage;
			}
		}
		
		part def SignalConditioner {
			port voltageIn : VoltageInPort;
			port voltageOut : VoltageOutPort;
			action def Condition {
				in v_in : AnalogVoltage;
				out v_out : AnalogVoltage;
			}
			perform action condition : Condition {
				in v_in = voltageIn.voltage;
				out v_out = voltageOut.voltage;
			}
		}
		
		part def ADC {
			port voltageIn : VoltageInPort;
			port digitalOut : DigitalPort;
			attribute resolution : Integer := 16;
			action def Convert {
				in v : AnalogVoltage;
				out d : DigitalReading;
			}
			perform action convert : Convert {
				in v = voltageIn.voltage;
				out d = digitalOut.reading;
			}
		}
		
		action def Initialize;
		action def SelfTest;
		action def SenseForce;
		action def AmplifyCharge;
		action def ConditionSignal;
		action def ConvertSignal;
		action def OutputReading;
		action def ReportFault;
		action def Diagnostics;
		
		state def SensingUnitStates {
			entry action initialize : Initialize;
			then state selfTest {
				do action selfTestAction : SelfTest;
			}
			then state operational {
				state sense {
					do action senseAction : SenseForce;
				}
				then amplify;
				state amplify {
					do action amplifyAction : AmplifyCharge;
				}
				then condition;
				state condition {
					do action conditionAction : ConditionSignal;
				}
				then convert;
				state convert {
					do action convertAction : ConvertSignal;
				}
				then output;
				state output {
					do action outputAction : OutputReading;
				}
				then sense;
			}
			accept FaultSignal then fault;
			state fault {
				do action reportFault : ReportFault;
				do action diagnostics : Diagnostics;
			}
			accept ResetSignal then selfTest;
		}
		
		part def PiezoelectricSensingUnit {
			port mechIn : MechanicalPort;
			port powerIn : PowerPort;
			port dataOut : DigitalPort;
			
			part sensor : PiezoelectricSensor;
			part amplifier : ChargeAmplifier;
			part conditioner : SignalConditioner;
			part adc : ADC;
			
			connection mechConn connect mechIn to sensor.mechIn;
			connection powerConn connect powerIn to amplifier.powerIn;
			connection chargeConn connect sensor.chargeOut to amplifier.chargeIn;
			connection voltageConn1 connect amplifier.voltageOut to conditioner.voltageIn;
			connection voltageConn2 connect conditioner.voltageOut to adc.voltageIn;
			connection digitalConn connect adc.digitalOut to dataOut;
			
			exhibit state unitStates : SensingUnitStates;
		}
		
		requirement def MeasurementRequirement {
			doc /* The unit shall measure physical pressure or force and convert it into a standardized 16-bit digital output. */
		}
		
		requirement def SamplingRateRequirement {
			doc /* The ADC shall sample the analog signal at a minimum rate of 10 kHz. */
		}
		
		requirement def FaultHandlingRequirement {
			doc /* The unit shall enter a fault state and run diagnostics upon detecting a fault signal. */
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part sensingUnit : PiezoelectricSensingUnit;
		
		requirement measureReq : MeasurementRequirement {
			subject = sensingUnit;
		}
		
		requirement samplingReq : SamplingRateRequirement {
			subject = sensingUnit;
		}
		
		requirement faultReq : FaultHandlingRequirement {
			subject = sensingUnit;
		}
	}
}
