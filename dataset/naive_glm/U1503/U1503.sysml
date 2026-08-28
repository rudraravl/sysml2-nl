package SolderingStationModel {
    import ScalarValues::*;

    // ---- Value Types ----
    value type Temperature :> Real { attribute unit : String = "degC"; }
    value type Power :> Real { attribute unit : String = "W"; }
    value type Voltage :> Real { attribute unit : String = "V"; }
    value type Current :> Real { attribute unit : String = "A"; }
    value type Resistance :> Real { attribute unit : String = "ohm"; }
    value type Length :> Real { attribute unit : String = "mm"; }
    value type Mass :> Real { attribute unit : String = "g"; }
    value type TimeValue :> Real { attribute unit : String = "s"; }
    value type Force :> Real { attribute unit : String = "N"; }
    value type Area :> Real { attribute unit : String = "mm2"; }
    value type Percentage :> Real { attribute unit : String = "%"; }

    // ---- Item Definitions ----
    item def SolderAlloy {
        attribute tinFraction : Percentage = 60;
        attribute leadFraction : Percentage = 40;
        attribute meltingPoint : Temperature = 183;
    }

    item def SolderWire {
        attribute alloy : SolderAlloy;
        attribute diameter : Length = 0.8;
        attribute spoolMass : Mass = 100;
    }

    item def ResistorComponent {
        attribute resistance : Resistance = 1000;
        attribute leadDiameter : Length = 0.6;
        attribute leadLength : Length = 10;
        attribute powerRating : Power = 0.25;
    }

    item def CircuitBoard {
        attribute padDiameter : Length = 1.5;
        attribute padArea : Area = 1.77;
        attribute boardThickness : Length = 1.6;
    }

    item def SolderJoint {
        attribute jointStrength : Force;
        attribute conductivityRating : Percentage;
        attribute passed : Boolean;
    }

    // ---- Port Definitions ----
    port def ElectricalPowerPort {
        out attribute voltage : Voltage;
        out attribute current : Current;
        out attribute power : Power;
    }

    port def ThermalPort {
        out attribute temperature : Temperature;
    }

    port def SensorSignalPort {
        out attribute measuredTemperature : Temperature;
    }

    port def ControlSignalPort {
        out attribute commandedPower : Power;
        out attribute targetTemperature : Temperature;
    }

    // ---- Part Definitions ----
    part def PowerSupply {
        port controlIn : ~ControlSignalPort;
        port powerOut : ElectricalPowerPort;
        attribute inputVoltage : Voltage = 230;
        attribute maxOutputPower : Power = 80;
        attribute currentOutputPower : Power = 0;
    }

    part def HeatingElement {
        port powerIn : ~ElectricalPowerPort;
        port thermalOut : ThermalPort;
        attribute maxPower : Power = 60;
        attribute currentTemperature : Temperature = 25;
        attribute resistance : Resistance = 8;
    }

    part def TemperatureSensor {
        port thermalIn : ~ThermalPort;
        port signalOut : SensorSignalPort;
        attribute accuracy : Temperature = 1;
        attribute measuredTemperature : Temperature = 25;
    }

    part def ControllerUnit {
        port sensorIn : ~SensorSignalPort;
        port controlOut : ControlSignalPort;
        attribute targetTemperature : Temperature = 320;
        attribute tolerance : Temperature = 5;
        attribute proportionalGain : Real = 2.0;
        attribute integralGain : Real = 0.1;
        attribute derivativeGain : Real = 0.05;
    }

    part def SolderingIron {
        part heatingElement : HeatingElement;
        part sensor : TemperatureSensor;
        port tipThermal : ThermalPort;
        attribute tipMass : Mass = 5;
    }

    // ---- Control Loop Action ----
    action def ControlLoop {
        in sensorReading : Temperature;
        in target : Temperature;
        in tolerance : Temperature;
        in maxPower : Power;
        out commandedPower : Power;

        if (sensorReading < target - tolerance) {
            assign commandedPower = maxPower;
        } else if (sensorReading > target + tolerance) {
            assign commandedPower = 0;
        } else {
            assign commandedPower = maxPower / 2;
        }
    }

    // ---- Requirements ----
    requirement def TemperatureStabilityRequirement {
        in targetTemp : Temperature;
        in tolerance : Temperature;
        in actualTemp : Temperature;
        require { constraint { (actualTemp - targetTemp) <= tolerance && (targetTemp - actualTemp) <= tolerance } }
    }

    requirement def JointStrengthRequirement {
        in minStrength : Force;
        in actualStrength : Force;
        require { constraint { actualStrength >= minStrength } }
    }

    requirement def ConductivityRequirement {
        in minConductivity : Percentage;
        in actualConductivity : Percentage;
        require { constraint { actualConductivity >= minConductivity } }
    }

    requirement def SolderMeltingRequirement {
        in meltingPoint : Temperature;
        in workingTemp : Temperature;
        require { constraint { workingTemp >= meltingPoint } }
    }

    requirement def SolderingStationRequirements {
        requirement tempStability : TemperatureStabilityRequirement {
            in targetTemp = 320;
            in tolerance = 5;
        }
        requirement jointStrength : JointStrengthRequirement {
            in minStrength = 20;
        }
        requirement conductivity : ConductivityRequirement {
            in minConductivity = 95;
        }
        requirement solderMelting : SolderMeltingRequirement {
            in meltingPoint = 183;
        }
    }

    // ---- Main Station ----
    part def SolderingStation {
        part powerSupply : PowerSupply;
        part controller : ControllerUnit;
        part iron : SolderingIron;
        attribute solderWire : SolderWire;
        attribute targetComponent : ResistorComponent;
        attribute targetBoard : CircuitBoard;
        attribute producedJoint : SolderJoint;

        // Connections
        connection powerToHeater connect powerSupply.powerOut to iron.heatingElement.powerIn;
        connection thermalToSensor connect iron.heatingElement.thermalOut to iron.sensor.thermalIn;
        connection sensorToController connect iron.sensor.signalOut to controller.sensorIn;
        connection controllerToPower connect controller.controlOut to powerSupply.controlIn;
        connection tipThermalConnect connect iron.heatingElement.thermalOut to iron.tipThermal;

        // Continuous control action
        action controlAction : ControlLoop {
            in sensorReading = iron.sensor.measuredTemperature;
            in target = controller.targetTemperature;
            in tolerance = controller.tolerance;
            in maxPower = iron.heatingElement.maxPower;
            out commandedPower = powerSupply.currentOutputPower;
        }

        // Soldering process state machine
        state machine SolderingProcess {
            state idle {
                entry assign powerSupply.currentOutputPower = 0;
            }
            state preheating {
                entry assign powerSupply.currentOutputPower = iron.heatingElement.maxPower;
            }
            state ready {
                entry assign powerSupply.currentOutputPower = iron.heatingElement.maxPower / 2;
            }
            state soldering {
                entry assign producedJoint.jointStrength = 25;
                entry assign producedJoint.conductivityRating = 97;
            }
            state cooling {
                entry assign powerSupply.currentOutputPower = 0;
            }
            state inspecting {
                entry assign producedJoint.passed = (producedJoint.jointStrength >= 20) && (producedJoint.conductivityRating >= 95);
            }
            state complete;
            state rework;

            transition startCycle
                from idle to preheating
                if (true);

            transition reachedTemp
                from preheating to ready
                if (iron.heatingElement.currentTemperature >= controller.targetTemperature - controller.tolerance);

            transition applySolder
                from ready to soldering
                if (true);

            transition solderApplied
                from soldering to cooling
                if (true);

            transition cooled
                from cooling to inspecting
                if (iron.heatingElement.currentTemperature < 100);

            transition jointAccepted
                from inspecting to complete
                if (producedJoint.passed == true);

            transition jointRejected
                from inspecting to rework
                if (producedJoint.passed == false);

            transition retry
                from rework to preheating
                if (true);
        }

        // Requirement satisfaction
        requirement tempStabilityReq : TemperatureStabilityRequirement {
            in targetTemp = controller.targetTemperature;
            in tolerance = controller.tolerance;
            in actualTemp = iron.heatingElement.currentTemperature;
        }
        requirement jointStrengthReq : JointStrengthRequirement {
            in minStrength = 20;
            in actualStrength = producedJoint.jointStrength;
        }
        requirement conductivityReq : ConductivityRequirement {
            in minConductivity = 95;
            in actualConductivity = producedJoint.conductivityRating;
        }
        requirement solderMeltingReq : SolderMeltingRequirement {
            in meltingPoint = solderWire.alloy.meltingPoint;
            in workingTemp = controller.targetTemperature;
        }
    }
}
