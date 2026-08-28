package IntelligentEndotrachealTubeSystem {
    import ScalarValues::*;

    // Units
    unit def cmH2O;
    unit def LperMin;
    unit def Percent;
    unit def mL;

    // Value Types
    value def PressureValue :> Real { unit cmH2O; }
    value def FlowValue :> Real { unit LperMin; }
    value def O2ConcentrationValue :> Real { unit Percent; }
    value def VolumeValue :> Real { unit mL; }

    // Item Definitions
    item def Air;
    item def PatientSecretions;

    // Port Definitions
    port def AirPort {
        in out item Air;
    }
    port def SensorDataPort {
        out pressure : PressureValue;
        out flow : FlowValue;
        out o2 : O2ConcentrationValue;
    }
    port def ControlDataPort {
        in pressure : PressureValue;
        in flow : FlowValue;
        in o2 : O2ConcentrationValue;
    }

    // Part Definitions
    part def TubeBody {
        attribute material : String = "Medical-grade PVC";
        port airIn : AirPort;
        port airOut : AirPort;
    }

    part def InflatableCuff {
        attribute cuffPressure : PressureValue;
        port airIn : AirPort;
        port sealPort; 
    }

    part def VentilationConnector {
        attribute diameter : Real = 15.0;
        port ventilatorSide : AirPort;
        port tubeSide : AirPort;
    }

    part def PressureSensor {
        port outPort : SensorDataPort;
        attribute measuredPressure : PressureValue;
    }

    part def FlowSensor {
        port outPort : SensorDataPort;
        attribute measuredFlow : FlowValue;
    }

    part def OxygenSensor {
        port outPort : SensorDataPort;
        attribute measuredO2 : O2ConcentrationValue;
    }

    part def SensorSuite {
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part oxygenSensor : OxygenSensor;
        port dataOut : SensorDataPort;
        
        connection pressureData connect pressureSensor.outPort.pressure to dataOut.pressure;
        connection flowData connect flowSensor.outPort.flow to dataOut.flow;
        connection o2Data connect oxygenSensor.outPort.o2 to dataOut.o2;
    }

    part def ControlUnit {
        port dataIn : ControlDataPort;
        attribute mode : String; 
        attribute alarmActive : Boolean = false;
    }

    part def IntelligentEndotrachealTube {
        part tubeBody : TubeBody;
        part cuff : InflatableCuff;
        part connector : VentilationConnector;
        part sensors : SensorSuite;
        part controller : ControlUnit;
        
        port ventilatorConnection : AirPort;
        port patientConnection : AirPort;
        
        connection ventilatorToConnector connect ventilatorConnection to connector.ventilatorSide;
        connection connectorToTube connect connector.tubeSide to tubeBody.airIn;
        connection tubeToPatient connect tubeBody.airOut to patientConnection;
        
        connection sensorData connect sensors.dataOut to controller.dataIn;
        
        exhibit {
            state Assessment;
            state Insertion;
            state Monitoring;
            state Adjustment;
            state Emergency;
            
            transition from Assessment to Insertion;
            transition from Insertion to Monitoring;
            transition from Monitoring to Adjustment;
            transition from Monitoring to Emergency;
            transition from Emergency to Monitoring;
            transition from Adjustment to Monitoring;
        }
    }

    // Requirements
    requirement def EstablishAirway {
        subject tube : IntelligentEndotrachealTube;
        require tube.tubeBody.material == "Medical-grade PVC";
    }

    requirement def SealTrachea {
        subject cuff : InflatableCuff;
        require cuff.cuffPressure > 0;
    }

    requirement def MonitorRespiratoryStatus {
        subject sensors : SensorSuite;
        require sensors.pressureSensor.measuredPressure > 0;
        require sensors.flowSensor.measuredFlow > 0;
        require sensors.oxygenSensor.measuredO2 > 0;
    }

    requirement def SafetyAlarms {
        subject controller : ControlUnit;
        require controller.alarmActive == true when controller.dataIn.pressure > 40;
    }
}
