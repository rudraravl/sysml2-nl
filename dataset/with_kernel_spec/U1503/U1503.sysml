package SolderingStationModel {
    private import ScalarValues::*;

    item def TemperatureValue :> Real;
    item def PowerValue :> Real;
    item def LengthValue :> Real;

    item def SolderWire {
        attribute composition : String;
        attribute meltingPoint : TemperatureValue;
        attribute diameter : LengthValue;
    }

    item def ElectricalComponent {
        attribute componentType : String;
        attribute leadCount : Integer;
    }

    item def CircuitBoard {
        attribute padSize : LengthValue;
    }

    item def SolderJoint {
        attribute strength : Real;
        attribute conductivity : Real;
        attribute isGood : Boolean;
    }

    part def HeatingElement {
        port powerIn {
            in power : PowerValue;
        }
        port tempOut {
            out temp : TemperatureValue;
        }
        attribute currentTemp : TemperatureValue;
    }

    part def TemperatureSensor {
        port tempIn {
            in temp : TemperatureValue;
        }
        port readingOut {
            out reading : TemperatureValue;
        }
    }

    part def ControllerUnit {
        port readingIn {
            in reading : TemperatureValue;
        }
        port targetIn {
            in target : TemperatureValue;
        }
        port powerOut {
            out power : PowerValue;
        }
        attribute targetTemp : TemperatureValue;
    }

    part def SolderingStationSystem {
        port targetTempPort {
            in target : TemperatureValue;
        }

        part controller : ControllerUnit;
        part heater : HeatingElement;
        part sensor : TemperatureSensor;

        flow powerFlow of PowerValue from controller.powerOut.power to heater.powerIn.power;
        flow tempFlow1 of TemperatureValue from heater.tempOut.temp to sensor.tempIn.temp;
        flow tempFlow2 of TemperatureValue from sensor.readingOut.reading to controller.readingIn.reading;

        part solderSpool : SolderWire {
            attribute composition = "Sn63Pb37";
            attribute meltingPoint = 183.0;
            attribute diameter = 0.8;
        }
        part pcb : CircuitBoard {
            attribute padSize = 1.5;
        }
        part componentToSolder : ElectricalComponent {
            attribute componentType = "Resistor";
            attribute leadCount = 2;
        }

        attribute producedJoint : SolderJoint;

        state machine SolderingProcess {
            initial state idle;
            state preheating;
            state soldering;
            state cooling;
            state inspecting;
            state complete;
            state rework;

            transition from idle to preheating accept "Start";
            transition from preheating to soldering when heater.currentTemp >= controller.targetTemp;
            transition from soldering to cooling after 5;
            transition from cooling to inspecting after 10;
            transition from inspecting to complete when producedJoint.isGood == true;
            transition from inspecting to rework when producedJoint.isGood == false;
            transition from rework to preheating accept "ReworkStart";
        }

        perform SolderingProcess;
    }

    requirement def SolderingStationRequirements {
        requirement tempControlReq {
            subject station : SolderingStationSystem;
            objective {
                doc "The station shall maintain a stable working temperature within a tight tolerance."
            }
        }
        requirement jointFormationReq {
            subject joint : SolderJoint;
            objective {
                doc "The station shall form a strong mechanical and electrically conductive joint."
            }
        }
        requirement qualityInspectionReq {
            subject joint : SolderJoint;
            objective {
                doc "The station shall ensure joint quality meets reliability standards."
            }
        }
    }
}
