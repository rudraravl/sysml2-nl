package AutomatedIrrigationSystem {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // =========================================================
    // Value Types with Units
    // =========================================================
    value type MoisturePercent :> Real {
        doc «Percentage of moisture in the soil by volume.»;
        unit : %[symbol "%"];
        constraint { 0 <= self and self <= 100 }
    }

    value type PressureValue :> Real {
        doc «Water pressure.»;
        unit : Pa;
    }

    value type FlowRateValue :> Real {
        doc «Volumetric flow rate of water.»;
        unit : 'm^3/s';
    }

    value type VolumeValue :> Real {
        doc «Volume of water.»;
        unit : 'm^3';
    }

    value type LengthValue :> Real {
        doc «Length (e.g., coverage radius).»;
        unit : m;
    }

    value type AngleValue :> Real {
        doc «Spray arc angle.»;
        unit : deg;
        constraint { 0 <= self and self <= 360 }
    }

    value type DurationValue :> Real {
        doc «Time duration.»;
        unit : s;
    }

    value type PowerValue :> Real {
        doc «Electrical power.»;
        unit : W;
    }

    // =========================================================
    // Enumerations
    // =========================================================
    enum def ValvePosition {
        CLOSED;
        PARTIALLY_OPEN;
        FULLY_OPEN;
    }

    enum def PumpStatus {
        OFF;
        ON;
        FAULT;
    }

    enum def SystemMode {
        MANUAL;
        AUTOMATIC;
        MAINTENANCE;
    }

    // =========================================================
    // Items and Signals
    // =========================================================
    item def Water {
        doc «Water as a physical substance.»;
        attribute density : Real = 1000 [kg/m^3];
        attribute potable : Boolean = true;
    }

    item def WaterFlow :> Water {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    item def MoistureReading {
        doc «Soil moisture reading transmitted by a sensor.»;
        attribute sensorId : String;
        attribute moisture : MoisturePercent;
        attribute timestamp : TimeValue;
    }

    item def ControlCommand {
        doc «Command sent from the controller to a device.»;
        attribute target : String;
        attribute action : String;
        attribute value : Real = 0;
    }

    // =========================================================
    // Port Definitions
    // =========================================================
    port def WaterInPort {
        in item waterFlow : Water;
    }

    port def WaterOutPort {
        out item waterFlow : Water;
    }

    port def WaterFlowOutPort {
        out item pressurizedWater : WaterFlow;
    }

    port def WaterFlowInPort {
        in item pressurizedWater : WaterFlow;
    }

    port def MoistureOutPort {
        out item reading : MoistureReading;
    }

    port def MoistureInPort {
        in item reading : MoistureReading;
    }

    port def CommandOutPort {
        out item command : ControlCommand;
    }

    port def CommandInPort {
        in item command : ControlCommand;
    }

    // =========================================================
    // Part Definitions
    // =========================================================
    part def WaterReservoir {
        doc «Central water storage that supplies water to the pump.»;
        port wOut : WaterOutPort;
        attribute capacity : VolumeValue = 10 [m^3];
        attribute currentVolume : VolumeValue = 10 [m^3];
        attribute minReserve : VolumeValue = 1 [m^3];

        action def dispense {
            in amount : VolumeValue;
            out dispensed : Water;
            constraint { amount <= currentVolume }
        }

        action def refill {
            in amount : VolumeValue;
            constraint { currentVolume + amount <= capacity }
        }

        compute updateVolume {
            in dispensedVolume : VolumeValue;
            out newVolume : VolumeValue;
        }
    }

    part def HighPressurePump {
        doc «Pump that draws water from the reservoir and pressurizes it for distribution.»;
        port wIn : WaterInPort;
        port wOut : WaterFlowOutPort;
        port cmdIn : CommandInPort;
        attribute power : PowerValue = 750 [W];
        attribute maxPressure : PressureValue = 5e5 [Pa];
        attribute nominalFlowRate : FlowRateValue = 0.01 [m^3/s];
        attribute status : PumpStatus = PumpStatus::OFF;

        action def pressurize {
            in inlet : Water;
            out outlet : WaterFlow;
        }

        action def start {
            constraint { currentVolume > 0 }
        }

        action def stop {}
    }

    part def PrimaryControlValve {
        doc «Valve that regulates flow and pressure to the sprinkler network.»;
        port wIn : WaterFlowInPort;
        port wOut : WaterFlowOutPort;
        port cmdIn : CommandInPort;
        attribute position : ValvePosition = ValvePosition::CLOSED;
        attribute openFraction : Real = 0 {
            constraint { 0 <= self and self <= 1 }
        }
        attribute maxFlowRate : FlowRateValue = 0.01 [m^3/s];

        action def setPosition {
            in newPos : ValvePosition;
        }

        action def openFully {}
        action def close {}
        action def setPartial {
            in fraction : Real;
            constraint { 0 < fraction and fraction < 1 }
        }
    }

    part def SprinklerHead {
        doc «Sprinkler that distributes water over a defined zone with a configured spray pattern.»;
        port wIn : WaterFlowInPort;
        attribute id : String;
        attribute zone : String;
        attribute sprayAngle : AngleValue;
        attribute coverageRadius : LengthValue;
        attribute isSpraying : Boolean = false;

        action def spray {
            in water : WaterFlow;
            out distributed : Water;
        }

        action def stopSpray {}
    }

    part def MoistureSensor {
        doc «Sensor that continuously measures soil moisture percentage at a fixed location.»;
        port mOut : MoistureOutPort;
        attribute id : String;
        attribute location : String;
        attribute measuredMoisture : MoisturePercent;
        attribute samplingInterval : DurationValue = 60 [s];
        attribute accuracy : Real = 2 [unit %];

        action def sense {
            out reading : MoistureReading;
        }

        action def calibrate {}
    }

    part def IrrigationController {
        doc «Central decision-making component that orchestrates watering cycles based on sensor feedback.»;
        port mIn : MoistureInPort;
        port cmdPump : CommandOutPort;
        port cmdValve : CommandOutPort;
        attribute minThreshold : MoisturePercent = 30 [%];
        attribute targetLevel : MoisturePercent = 60 [%];
        attribute mode : SystemMode = SystemMode::AUTOMATIC;
        attribute cycleActive : Boolean = false;

        action def evaluateReadings {
            in readings : MoistureReading[*];
            out shouldStart : Boolean;
            out shouldStop : Boolean;
            constraint { not (shouldStart and shouldStop) }
        }

        action def issueCommand {
            in cmd : ControlCommand;
        }

        state machine controllerBehavior {
            state idle {
                doc «Monitoring sensors and awaiting trigger.»;
                entry action {
                    cycleActive := false;
                }
            }
            state watering {
                doc «Pump running and valve open while soil moisture is below target.»;
                entry action {
                    cycleActive := true;
                }
            }
            state fault {
                doc «Error state; actuation suspended.»;
            }

            initial state idle;

            transition from idle to watering
                when mIn.reading.moisture < minThreshold
                do action {
                    issueCommand(ControlCommand{target := "pump", action := "start"});
                    issueCommand(ControlCommand{target := "valve", action := "open", value := 1.0});
                }

            transition from watering to idle
                when mIn.reading.moisture >= targetLevel
                do action {
                    issueCommand(ControlCommand{target := "valve", action := "close"});
                    issueCommand(ControlCommand{target := "pump", action := "stop"});
                }

            transition from idle to fault
                when mode == SystemMode::MAINTENANCE;

            transition from watering to fault
                when mode == SystemMode::MAINTENANCE;

            transition from fault to idle
                when mode != SystemMode::MAINTENANCE;
        }
    }

    // =========================================================
    // Top-Level System Assembly
    // =========================================================
    part irrigationSystem {
        doc «Self-regulating automated irrigation system for fields and large landscaped areas.»;
        part reservoir : WaterReservoir {
            attribute currentVolume : VolumeValue = 8 [m^3];
        }
        part pump : HighPressurePump;
        part valve : PrimaryControlValve;
        part sprinklers[4] : SprinklerHead {
            attribute sprayAngle : AngleValue;
            attribute coverageRadius : LengthValue = 6 [m];
        }
        part sensors[3] : MoistureSensor {
            attribute samplingInterval : DurationValue = 60 [s];
        }
        part controller : IrrigationController {
            attribute minThreshold : MoisturePercent = 30 [%];
            attribute targetLevel : MoisturePercent = 60 [%];
        }

        // Water delivery chain
        connection w1 connect reservoir.wOut to pump.wIn;
        connection w2 connect pump.wOut to valve.wIn;
        connection w3 connect valve.wOut to sprinklers.wIn;

        // Sensor telemetry chain
        connection s1 connect sensors.mOut to controller.mIn;

        // Command chain
        connection c1 connect controller.cmdPump to pump.cmdIn;
        connection c2 connect controller.cmdValve to valve.cmdIn;
    }

    // =========================================================
    // Sprinkler zone configuration
    // =========================================================
    part sprinklerZones :> irrigationSystem.sprinklers {
        item s1 : SprinklerHead { attribute id := "SP1"; attribute zone := "A1"; attribute sprayAngle := 180 [deg]; }
        item s2 : SprinklerHead { attribute id := "SP2"; attribute zone := "A2"; attribute sprayAngle := 360 [deg]; }
        item s3 : SprinklerHead { attribute id := "SP3"; attribute zone := "B1"; attribute sprayAngle := 180 [deg]; }
        item s4 : SprinklerHead { attribute id := "SP4"; attribute zone := "B2"; attribute sprayAngle := 360 [deg]; }
    }

    // =========================================================
    // Requirements
    // =========================================================
    requirement def IrrigationSystemRequirements {
        doc «Top-level requirements for the automated irrigation system.»;
    }

    requirement moistureMaintenance : IrrigationSystemRequirements {
        doc «The system shall maintain soil moisture between a minimum threshold and a target level.»;
        subject sys : irrigationSystem;
        constraint { 30 [%] <= sys.sensors.measuredMoisture and sys.sensors.measuredMoisture <= 60 [%] }
    }

    requirement automaticWatering : IrrigationSystemRequirements {
        doc «The system shall automatically initiate a watering cycle when soil moisture falls below the minimum threshold.»;
        subject sys : irrigationSystem;
        constraint { 
            (sys.sensors.measuredMoisture < 30 [%]) implies
            (sys.controller.cycleActive == true)
        }
    }

    requirement waterConservation : IrrigationSystemRequirements {
        doc «The system shall close the valve and shut down the pump once target soil moisture is reached.»;
        subject sys : irrigationSystem;
        constraint {
            (sys.sensors.measuredMoisture >= 60 [%]) implies
            (sys.valve.position == ValvePosition::CLOSED and sys.pump.status == PumpStatus::OFF)
        }
    }

    requirement reservoirCapacity : IrrigationSystemRequirements {
        doc «The reservoir shall store at least 10 m^3 of water for irrigation cycles.»;
        subject res : WaterReservoir;
        constraint { res.capacity >= 10 [m^3] }
    }

    requirement pumpPressure : IrrigationSystemRequirements {
        doc «The pump shall deliver water at sufficient pressure to operate all four sprinkler heads.»;
        subject p : HighPressurePump;
        constraint { p.maxPressure >= 4e5 [Pa] }
    }

    requirement valveControl : IrrigationSystemRequirements {
        doc «The primary valve shall support closed, partially open, and fully open positions.»;
        subject v : PrimaryControlValve;
        constraint { 
            v.position in {ValvePosition::CLOSED, ValvePosition::PARTIALLY_OPEN, ValvePosition::FULLY_OPEN}
        }
    }

    requirement sprinklerCoverage : IrrigationSystemRequirements {
        doc «The four sprinkler heads shall provide comprehensive coverage using 180° and 360° spray patterns.»;
        subject sys : irrigationSystem;
        constraint { 
            count(sys.sprinklers) == 4 and 
            exists(sys.sprinklers.sprayAngle == 180 [deg]) and 
            exists(sys.sprinklers.sprayAngle == 360 [deg])
        }
    }

    requirement continuousMonitoring : IrrigationSystemRequirements {
        doc «Moisture sensors shall continuously provide readings to the controller for real-time decisions.»;
        subject sys : irrigationSystem;
        constraint {
            all s : sys.sensors | s.samplingInterval <= 60 [s]
        }
    }

    satisfaction moistureSat satisfy moistureMaintenance by irrigationSystem;
    satisfaction automaticSat satisfy automaticWatering by irrigationSystem;
    satisfaction conservationSat satisfy waterConservation by irrigationSystem;
    satisfaction reservoirSat satisfy reservoirCapacity by WaterReservoir;
    satisfaction pumpSat satisfy pumpPressure by HighPressurePump;
    satisfaction valveSat satisfy valveControl by PrimaryControlValve;
    satisfaction coverageSat satisfy sprinklerCoverage by irrigationSystem;
    satisfaction monitoringSat satisfy continuousMonitoring by MoistureSensor;
}
