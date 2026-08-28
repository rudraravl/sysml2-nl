package AccelerometerSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQElectricity::*;
    import ISQThermodynamics::*;
    import ISQTime::*;

    attribute def AccelerationVector {
        attr x : Acceleration;
        attr y : Acceleration;
        attr z : Acceleration;
    }

    attribute def VoltageValue {
        attr value : ElectricPotential;
    }

    attribute def DigitalSample {
        attr value : Integer;
    }

    attribute def AccelerometerStatus {
        attr temperature : ThermodynamicTemperature;
        attr isCalibrated : Boolean;
        attr isError : Boolean;
    }

    attribute def ConfigParameters {
        attr samplingRate : Frequency;
        attr sensitivity : Real;
    }

    enum def CommandType {
        idle;
        calibrate;
        measure;
        stop;
        reset;
    }

    attribute def AccelerometerCommand {
        attr commandType : CommandType;
    }

    port def AnalogSignalPort {
        out voltage : VoltageValue;
    }

    port def DigitalDataPort {
        out sample : DigitalSample;
    }

    port def AccelerationDataOutPort {
        out acceleration : AccelerationVector;
    }

    port def StatusOutPort {
        out status : AccelerometerStatus;
    }

    port def ConfigInPort {
        in config : ConfigParameters;
    }

    port def CommandInPort {
        in command : AccelerometerCommand;
    }

    part def ProofMass {
        attr mass : Mass;
    }

    part def SensingElement {
        attr axisLabel : String;
        attr springConstant : Real;
        part proofMass : ProofMass;
        port analogOut : out AnalogSignalPort;
    }

    part def SignalConditioner {
        port analogIn : in AnalogSignalPort;
        port analogOut : out AnalogSignalPort;
        action amplifyAndFilter;
    }

    part def ADC {
        port analogIn : in AnalogSignalPort;
        port digitalOut : out DigitalDataPort;
        action convertAnalogToDigital;
    }

    part def DataProcessor {
        port digitalInX : in DigitalDataPort;
        port digitalInY : in DigitalDataPort;
        port digitalInZ : in DigitalDataPort;
        
        port dataOut : out AccelerationDataOutPort;
        port statusOut : out StatusOutPort;
        
        port configIn : in ConfigInPort;
        port commandIn : in CommandInPort;

        attr calibrationMatrix : Real[3,3];
        attr offsetCorrection : AccelerationVector;
        
        action applyCalibrationAndOffset;
    }

    part def ThreeAxisAccelerometer {
        part xSensing : SensingElement { :>> axisLabel = "X"; }
        part ySensing : SensingElement { :>> axisLabel = "Y"; }
        part zSensing : SensingElement { :>> axisLabel = "Z"; }

        part xConditioner : SignalConditioner;
        part yConditioner : SignalConditioner;
        part zConditioner : SignalConditioner;

        part xAdc : ADC;
        part yAdc : ADC;
        part zAdc : ADC;

        part processor : DataProcessor;

        port accelDataPort : out AccelerationDataOutPort;
        port statusPort : out StatusOutPort;
        port configPort : in ConfigInPort;
        port commandPort : in CommandInPort;

        connect xSensing.analogOut to xConditioner.analogIn;
        connect xConditioner.analogOut to xAdc.analogIn;
        connect xAdc.digitalOut to processor.digitalInX;

        connect ySensing.analogOut to yConditioner.analogIn;
        connect yConditioner.analogOut to yAdc.analogIn;
        connect yAdc.digitalOut to processor.digitalInY;

        connect zSensing.analogOut to zConditioner.analogIn;
        connect zConditioner.analogOut to zAdc.analogIn;
        connect zAdc.digitalOut to processor.digitalInZ;

        connect processor.dataOut to accelDataPort;
        connect processor.statusOut to statusPort;
        connect configPort to processor.configIn;
        connect commandPort to processor.commandIn;

        state def AccelerometerStateMachine {
            state idle;
            state calibrating;
            state measuring;
            state fault;

            transition initial to idle;
            
            transition idle to calibrating when commandPort.command.commandType == CommandType::calibrate;
            transition calibrating to idle when processor.statusOut.status.isCalibrated;
            transition idle to measuring when commandPort.command.commandType == CommandType::measure;
            transition measuring to idle when commandPort.command.commandType == CommandType::stop;
            transition measuring to fault when processor.statusOut.status.isError;
            transition idle to fault when processor.statusOut.status.isError;
            transition fault to idle when commandPort.command.commandType == CommandType::reset;
        }
        exhibit AccelerometerStateMachine;
    }

    requirement def AccelerometerSystemRequirements {
        doc <<Requirements for the three-axis digital accelerometer system.>>
        requirement MeasurementRequirement {
            doc <<The system shall measure linear acceleration along the X, Y, and Z axes.>>
        }
        requirement StatusOutputRequirement {
            doc <<The system shall output its operational status, including temperature and calibration state.>>
        }
        requirement StateMachineRequirement {
            doc <<The system shall support idle, calibrating, measuring, and fault operational states.>>
        }
        requirement ConfigurationRequirement {
            doc <<The system shall allow external configuration of sampling rate and sensitivity.>>
        }
    }
}
