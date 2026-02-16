package HandyBillySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def RotationalSpeedValue :> Real;

    item def Water;
    item def Fuel;
    item def ExhaustGas;

    port def WaterInletPort {
        in item water : Water;
        attribute inletPressure : PressureValue;
    }

    port def WaterOutletPort {
        out item water : Water;
        attribute outletPressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def FuelSupplyPort {
        in item fuel : Fuel;
    }

    port def ExhaustPort {
        out item exhaust : ExhaustGas;
    }

    port def MechanicalDrivePort {
        attribute torque : ISQ::TorqueValue;
        attribute speed : RotationalSpeedValue;
    }

    part def GasolineEngine {
        attribute displacement : ISQ::VolumeValue;
        attribute ratedPower : PowerValue;
        attribute operatingSpeed : RotationalSpeedValue;
        attribute mass : ISQ::MassValue;

        port fuelInlet : FuelSupplyPort;
        port exhaustOutlet : ExhaustPort;
        port powerOutput : MechanicalDrivePort;

        perform action operateEngine {
            in fuelFlow : Fuel;
            out mechanicalOutput : PowerValue;
            out exhaustEmission : ExhaustGas;
        }
    }

    part def CentrifugalPump {
        attribute maxFlowRate : FlowRateValue;
        attribute maxPressure : PressureValue;
        attribute efficiency : Real;
        attribute mass : ISQ::MassValue;

        port waterIn : WaterInletPort;
        port waterOut : WaterOutletPort;
        port driveInput : MechanicalDrivePort;

        perform action pumpFluid {
            in drivePower : PowerValue;
            in incomingWater : Water;
            out dischargedWater : Water;
            out actualFlowRate : FlowRateValue;
            out actualPressure : PressureValue;
        }
    }

    part def SuctionHose {
        attribute length : ISQ::LengthValue;
        attribute innerDiameter : ISQ::LengthValue;
        attribute mass : ISQ::MassValue;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
    }

    part def DischargeHose {
        attribute length : ISQ::LengthValue;
        attribute innerDiameter : ISQ::LengthValue;
        attribute mass : ISQ::MassValue;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
    }

    part def FuelTank {
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;
        attribute mass : ISQ::MassValue;

        port fuelOutput : FuelSupplyPort;
    }

    part def Strainer {
        attribute meshSize : ISQ::LengthValue;
        attribute mass : ISQ::MassValue;

        port waterIn : WaterInletPort;
        port waterOut : WaterOutletPort;
    }

    part def DischargeNozzle {
        attribute nozzleDiameter : ISQ::LengthValue;
        attribute mass : ISQ::MassValue;

        port waterIn : WaterInletPort;

        perform action dischargeStream {
            in pressurizedWater : Water;
            in pressure : PressureValue;
            out waterJet : Water;
        }
    }

    part def MountingFrame {
        attribute material : String;
        attribute frameMass : ISQ::MassValue;
    }

    connection def MechanicalCoupling {
        end source : MechanicalDrivePort;
        end target : MechanicalDrivePort;
    }

    part def HandyBilly {
        part mountingFrame : MountingFrame {
            attribute material = "Galvanized Steel";
            attribute frameMass = 8.0 [kg];
        }

        part engine : GasolineEngine {
            attribute displacement = 163.0 [m^3] * 1.0e-6;
            attribute ratedPower = 4.0 [kW];
            attribute operatingSpeed = 3600.0;
            attribute mass = 15.0 [kg];
        }

        part pump : CentrifugalPump {
            attribute maxFlowRate = 250.0 [m^3/s] * (1.0/60000.0);
            attribute maxPressure = 600.0 [kPa];
            attribute efficiency = 0.70;
            attribute mass = 12.0 [kg];
        }

        part fuelTank : FuelTank {
            attribute capacity = 3.8 [m^3] * 0.001;
            attribute currentLevel = 3.8 [m^3] * 0.001;
            attribute mass = 2.0 [kg];
        }

        part suctionHose : SuctionHose {
            attribute length = 6.0 [m];
            attribute innerDiameter = 50.0 [mm];
            attribute mass = 3.5 [kg];
        }

        part dischargeHose : DischargeHose {
            attribute length = 15.0 [m];
            attribute innerDiameter = 38.0 [mm];
            attribute mass = 5.0 [kg];
        }

        part strainer : Strainer {
            attribute meshSize = 3.0 [mm];
            attribute mass = 1.5 [kg];
        }

        part nozzle : DischargeNozzle {
            attribute nozzleDiameter = 25.0 [mm];
            attribute mass = 0.8 [kg];
        }

        port suctionPoint : WaterInletPort;
        port dischargePoint : WaterOutletPort;

        connection fuelLine connect fuelTank.fuelOutput to engine.fuelInlet;
        connection driveCoupling : MechanicalCoupling connect engine.powerOutput to pump.driveInput;
        connection suctionPath connect suctionPoint to strainer.waterIn;
        connection strainerToPump connect strainer.waterOut to suctionHose.inlet;
        connection hoseToPump connect suctionHose.outlet to pump.waterIn;
        connection pumpToDischarge connect pump.waterOut to dischargeHose.inlet;
        connection hoseToNozzle connect dischargeHose.outlet to nozzle.waterIn;
        connection nozzleToDischarge connect nozzle.waterIn to dischargePoint;

        attribute totalMass : ISQ::MassValue;

        perform action operateHandyBilly {
            first start;
            then action primeSystem {
                doc /* Fill suction hose and pump with water to eliminate air. */
            }
            then action startEngine {
                ref part :>> engine;
            }
            then action establishFlow {
                ref part :>> pump;
                ref part :>> engine;
            }
            then action deliverWater {
                ref part :>> nozzle;
                ref part :>> pump;
            }
            then action shutdownEngine {
                ref part :>> engine;
            }
            then done;
        }
    }

    action def EmergencyDewateringOperation {
        in waterSource : Water;
        in requiredFlowRate : FlowRateValue;
        in requiredPressure : PressureValue;
        out deliveredWater : Water;
        out achievedFlowRate : FlowRateValue;

        first start;
        then action deployEquipment {
            doc /* Position Handy Billy and connect hoses to water source and discharge point. */
        }
        then action primeAndStart {
            doc /* Prime pump and start engine. */
        }
        then action pumpWater {
            in source : Water;
            in targetFlow : FlowRateValue;
            out pumpedWater : Water;
            out actualFlow : FlowRateValue;
        }
        then action monitorOperation {
            in currentFlow : FlowRateValue;
            in currentPressure : PressureValue;
        }
        then action shutdown {
            doc /* Stop engine and secure equipment. */
        }
        then done;
    }

    state def HandyBillyOperationalStates {
        entry; then idle;

        state idle;

        accept StartupCommand;
        then state priming {
            do action fillSuctionLine;
        }

        accept PrimingComplete;
        then state engineStarting {
            do action crankEngine;
        }

        accept EngineRunning;
        then state operational {
            do action maintainFlow;

            state normalOperation;
            state reducedFlow;

            accept FlowReduction;
            then reducedFlow;
        }

        accept ShutdownCommand;
        then state shuttingDown {
            do action stopEngine;
            do action drainSystem;
        }

        then idle;

        state fault {
            state lowFuel;
            state cavitation;
            state overheating;
        }

        accept FaultDetected;
        then fault;
    }

    requirement def <'HB-REQ-001'> primaryFunctionRequirement {
        doc /* The Handy Billy shall provide portable emergency pumping capability 
                for firefighting, dewatering, and general water transfer operations. */

        subject handyBilly : HandyBilly;

        require <'HB-REQ-001.1'> minimumFlowRate {
            doc /* The system shall deliver a minimum flow rate of 200 liters per minute 
                    at rated operating conditions. */
            attribute requiredFlowRate : FlowRateValue = 200.0 [m^3/s] * (1.0/60000.0);
        }

        require <'HB-REQ-001.2'> minimumDischargePressure {
            doc /* The system shall generate a minimum discharge pressure of 500 kPa 
                    at rated flow. */
            attribute requiredPressure : PressureValue = 500.0 [kPa];
        }

        require <'HB-REQ-001.3'> portabilityRequirement {
            doc /* The complete system dry weight shall not exceed 50 kg to enable 
                    manual handling by two persons. */
            attribute maxWeight : ISQ::MassValue = 50.0 [kg];
        }

        require <'HB-REQ-001.4'> operationalEndurance {
            doc /* The system shall operate continuously for at least 2 hours 
                    on a full fuel tank at rated capacity. */
            attribute minRunTime : ISQ::DurationValue = 2.0 [h];
        }

        require <'HB-REQ-001.5'> suctionLift {
            doc /* The system shall achieve a minimum suction lift of 4 meters 
                    from water source to pump centerline. */
            attribute minSuctionLift : ISQ::LengthValue = 4.0 [m];
        }
    }

    requirement <'HB-REQ-002'> rapidDeploymentRequirement {
        doc /* The Handy Billy shall be capable of rapid deployment and operation 
                in emergency scenarios. */

        assume constraint quickSetup {
            doc /* System can be deployed from storage to operational status 
                    within 3 minutes by trained personnel. */
        }

        require primaryFunctionRequirement;
    }

    requirement <'HB-REQ-003'> reliabilityRequirement {
        doc /* The Handy Billy shall demonstrate high reliability in marine 
                and industrial environments. */

        require constraint corrosionResistance {
            doc /* All wetted components shall be constructed from corrosion-resistant 
                    materials suitable for saltwater service. */
        }

        require constraint vibrationTolerance {
            doc /* The system shall withstand continuous vibration during operation 
                    without mechanical failure. */
        }
    }

    part handyBillyUnit : HandyBilly {
        satisfy primaryFunctionRequirement by handyBillyUnit;
        satisfy rapidDeploymentRequirement by handyBillyUnit;
        satisfy reliabilityRequirement by handyBillyUnit;

        perform action emergencyResponse : EmergencyDewateringOperation {
            in waterSource;
            in requiredFlowRate = 220.0 [m^3/s] * (1.0/60000.0);
            in requiredPressure = 550.0 [kPa];
            out deliveredWater;
            out achievedFlowRate;
        }
    }
}
