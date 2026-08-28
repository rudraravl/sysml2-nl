import ScalarValues::*;

package DaikinSplitSystemAC {
    value type Celsius :> Real;
    value type Percent :> Real;
    value type RPM :> Real;
    value type MassFlowRate :> Real;
    value type Pressure :> Real;
    value type VolumeFlowRate :> Real;
    value type Power :> Real;

    item def Refrigerant;
    item def Air;

    port def RefrigerantPort {
        attribute temp : Celsius;
        attribute pressure : Pressure;
        attribute flowRate : MassFlowRate;
    }

    port def AirPort {
        attribute temp : Celsius;
        attribute humidity : Percent;
        attribute flowRate : VolumeFlowRate;
    }

    port def ControlPort {
        attribute command : String;
        attribute setPoint : Celsius;
        attribute fanSpeedSetting : Integer;
        attribute compressorSpeed : RPM;
    }

    port def SensorPort {
        attribute temp : Celsius;
        attribute humidity : Percent;
    }

    part def HeatExchanger {
        attribute efficiency : Real;
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        port airIn : AirPort;
        port airOut : AirPort;
    }

    part def Fan {
        attribute currentSpeed : RPM;
        port control : ControlPort;
        port airIn : AirPort;
        port airOut : AirPort;
    }

    part def InverterCompressor {
        attribute currentSpeed : RPM;
        port control : ControlPort;
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
    }

    part def ExpansionValve {
        attribute openingDegree : Percent;
        port control : ControlPort;
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
    }

    part def ReversingValve {
        attribute isHeatingMode : Boolean;
        port control : ControlPort;
        port refrigerantFromCompressor : RefrigerantPort;
        port refrigerantFromIndoor : RefrigerantPort;
        port refrigerantToCondenser : RefrigerantPort;
        port refrigerantToIndoor : RefrigerantPort;
    }

    part def Sensor {
        port sensorData : SensorPort;
    }

    part def InverterController {
        attribute currentMode : String;
        attribute setPoint : Celsius;
        port userCommand : ControlPort;
        port sensorInput : SensorPort;
        port outdoorControl : ControlPort;
        port indoorControl : ControlPort;

        state machine ControlBehavior {
            state Off {
                entry action {
                    outdoorControl.command = "Off";
                    indoorControl.command = "Off";
                }
            }
            state Cooling {
                entry action {
                    outdoorControl.command = "Cool";
                    indoorControl.command = "Cool";
                }
            }
            state Heating {
                entry action {
                    outdoorControl.command = "Heat";
                    indoorControl.command = "Heat";
                }
            }
            state Dehumidifying {
                entry action {
                    outdoorControl.command = "CoolLow";
                    indoorControl.command = "Dry";
                }
            }
            state FanOnly {
                entry action {
                    outdoorControl.command = "Off";
                    indoorControl.command = "Fan";
                }
            }
            state Auto {
                entry action {
                    outdoorControl.command = "Auto";
                    indoorControl.command = "Auto";
                }
            }

            transition initial to Off;
            transition Off to Cooling when (userCommand.command == "Cooling");
            transition Off to Heating when (userCommand.command == "Heating");
            transition Off to Dehumidifying when (userCommand.command == "Dehumidifying");
            transition Off to FanOnly when (userCommand.command == "FanOnly");
            transition Off to Auto when (userCommand.command == "Auto");

            transition Cooling to Off when (userCommand.command == "Off");
            transition Heating to Off when (userCommand.command == "Off");
            transition Dehumidifying to Off when (userCommand.command == "Off");
            transition FanOnly to Off when (userCommand.command == "Off");
            transition Auto to Off when (userCommand.command == "Off");

            transition Auto to Cooling when (sensorInput.temp > userCommand.setPoint + 1.0);
            transition Auto to Heating when (sensorInput.temp < userCommand.setPoint - 1.0);
        }
    }

    part def OutdoorUnit {
        part compressor : InverterCompressor;
        part condenser : HeatExchanger;
        part outdoorFan : Fan;
        part reversingValve : ReversingValve;

        port refrigerantFromIndoor : RefrigerantPort;
        port refrigerantToIndoor : RefrigerantPort;
        port ambientAirIn : AirPort;
        port ambientAirOut : AirPort;
        port control : ControlPort;

        connect control to compressor.control;
        connect control to reversingValve.control;
        connect control to outdoorFan.control;
        
        connect refrigerantFromIndoor to compressor.refrigerantIn;
        connect compressor.refrigerantOut to reversingValve.refrigerantFromCompressor;
        connect reversingValve.refrigerantToCondenser to condenser.refrigerantIn;
        connect condenser.refrigerantOut to reversingValve.refrigerantFromIndoor;
        connect reversingValve.refrigerantToIndoor to refrigerantToIndoor;

        connect ambientAirIn to outdoorFan.airIn;
        connect outdoorFan.airOut to condenser.airIn;
        connect condenser.airOut to ambientAirOut;
    }

    part def IndoorUnit {
        part evaporator : HeatExchanger;
        part blower : Fan;
        part expansionValve : ExpansionValve;
        part sensor : Sensor;

        port refrigerantFromOutdoor : RefrigerantPort;
        port refrigerantToOutdoor : RefrigerantPort;
        port roomAirIn : AirPort;
        port roomAirOut : AirPort;
        port control : ControlPort;
        port sensorData : SensorPort;

        connect control to expansionValve.control;
        connect control to blower.control;

        connect refrigerantFromOutdoor to expansionValve.refrigerantIn;
        connect expansionValve.refrigerantOut to evaporator.refrigerantIn;
        connect evaporator.refrigerantOut to refrigerantToOutdoor;

        connect roomAirIn to blower.airIn;
        connect blower.airOut to evaporator.airIn;
        connect evaporator.airOut to roomAirOut;

        connect sensor.sensorData to sensorData;
    }

    part def SplitSystemAC {
        part outdoorUnit : OutdoorUnit;
        part indoorUnit : IndoorUnit;
        part controller : InverterController;

        connect outdoorUnit.refrigerantToIndoor to indoorUnit.refrigerantFromOutdoor;
        connect indoorUnit.refrigerantToOutdoor to outdoorUnit.refrigerantFromIndoor;

        connect controller.outdoorControl to outdoorUnit.control;
        connect controller.indoorControl to indoorUnit.control;
        connect indoorUnit.sensorData to controller.sensorInput;
    }

    requirement def ClimateControlRequirement {
        doc /* The system shall maintain the desired indoor temperature. */
    }
    requirement def EfficiencyRequirement {
        doc /* The inverter compressor shall adjust its speed to match the thermal load. */
    }
    requirement def ModeRequirement {
        doc /* The system shall support Cooling, Heating, Dehumidifying, FanOnly, and Auto modes. */
    }
    requirement def MoistureRemovalRequirement {
        doc /* The system shall effectively remove moisture from the air in dehumidifying mode. */
    }

    requirement climateReq : ClimateControlRequirement {
        subject system : SplitSystemAC;
    }
    requirement efficiencyReq : EfficiencyRequirement {
        subject compressor : InverterCompressor;
    }
    requirement modeReq : ModeRequirement {
        subject controller : InverterController;
    }
    requirement moistureReq : MoistureRemovalRequirement {
        subject system : SplitSystemAC;
    }
}
