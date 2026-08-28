package HydraulicRamPump {
    import ISQ::*;
    import ISQBase::*;
    import ScalarValues::*;
    import Time::*;

    // ---------- Item Definitions ----------
    item def Water {
        attribute density :> MassDensity = 1000.0 [kg/m^3];
        attribute dynamicViscosity :> DynamicViscosity = 1.0e-3 [Pa*s];
    }

    item def Air {
        attribute specificHeatRatio : Real = 1.4;
        attribute initialPressure :> Pressure = 101.325 [kPa];
    }

    item def WaterAirMixture {
        attribute waterFraction : Real;
        attribute airFraction : Real;
    }

    // ---------- Value Types ----------
    attribute def HydraulicPressure :> Pressure;
    attribute def FlowVelocity :> Speed;
    attribute def PipeFlowRate :> VolumeFlowRate;
    attribute def ElevationHead :> Length;
    attribute def PipeDiameter :> Length;
    attribute def PipeLength :> Length;
    attribute def ValveOpeningArea :> Area;
    attribute def AirVolume :> Volume;
    attribute def WaterVolume :> Volume;
    attribute def CyclePeriod :> Duration;
    attribute def ImpulseThresholdVelocity :> Speed;

    // ---------- Port Definitions ----------
    port def FluidInPort {
        in item water : Water;
        in attribute pressure : HydraulicPressure;
        in attribute flowRate : PipeFlowRate;
        in attribute velocity : FlowVelocity;
    }

    port def FluidOutPort {
        out item water : Water;
        out attribute pressure : HydraulicPressure;
        out attribute flowRate : PipeFlowRate;
        out attribute velocity : FlowVelocity;
    }

    port def BidirectionalFluidPort {
        item water : Water;
        attribute pressure : HydraulicPressure;
        attribute flowRate : PipeFlowRate;
        attribute velocity : FlowVelocity;
    }

    port def MechanicalSignalPort {
        attribute position : Real; // 0 = closed, 1 = open
        attribute force :> Force;
    }

    // ---------- Requirements ----------
    requirement def PumpingRequirement {
        attribute targetLiftHeight : ElevationHead = 30.0 [m];
        attribute sourceHead : ElevationHead = 2.0 [m];
        attribute requiredDeliveryFlow : PipeFlowRate = 0.5 [L/min];
        subject pump :> HydraulicRamPump::RamPump;
        require pump.deliveryFlowRate >= requiredDeliveryFlow
            and pump.deliveryHead >= targetLiftHeight;
    }

    requirement def SelfOperationRequirement {
        attribute maxCyclePeriod : CyclePeriod = 2.0 [s];
        subject pump :> HydraulicRamPump::RamPump;
        require pump.operatesWithoutExternalPower
            and pump.cyclePeriod <= maxCyclePeriod;
    }

    requirement def DrivePipeRequirement {
        attribute minLength : PipeLength = 5.0 [m];
        attribute maxLength : PipeLength = 100.0 [m];
        attribute minDiameter : PipeDiameter = 25.0 [mm];
        subject drivePipe :> HydraulicRamPump::DrivePipe;
        require drivePipe.length >= minLength
            and drivePipe.length <= maxLength
            and drivePipe.diameter >= minDiameter
            and drivePipe.material = "rigid";
    }

    requirement def AirChamberRequirement {
        attribute minAirVolume : AirVolume = 1.0 [L];
        attribute maxPressure : HydraulicPressure = 500.0 [kPa];
        subject chamber :> HydraulicRamPump::AirChamber;
        require chamber.initialAirVolume >= minAirVolume
            and chamber.maxOperatingPressure <= maxPressure;
    }

    // ---------- Part Definitions ----------
    part def WaterSource {
        attribute elevation : ElevationHead = 2.0 [m];
        attribute availableFlow : PipeFlowRate = 50.0 [L/min];
        port fluidOut : FluidOutPort;
    }

    part def DrivePipe {
        attribute length : PipeLength = 10.0 [m];
        attribute diameter : PipeDiameter = 40.0 [mm];
        attribute material : String = "steel";
        attribute roughness : Real = 0.00015;
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        attribute flowVelocity : FlowVelocity;
        attribute flowRate : PipeFlowRate;
        attribute pressureDrop : HydraulicPressure;

        action def AccelerateFlow {
            in initialVelocity : FlowVelocity;
            in head : ElevationHead;
            out finalVelocity : FlowVelocity;
            // v = sqrt(2*g*head) simplified
        }
    }

    part def ImpulseValve {
        attribute isOpen : Boolean = true;
        attribute openingArea : ValveOpeningArea;
        attribute maxArea : ValveOpeningArea = 5.0e-3 [m^2];
        attribute thresholdVelocity : ImpulseThresholdVelocity = 1.5 [m/s];
        attribute mass :> Mass = 0.5 [kg];
        port driveSide : BidirectionalFluidPort;
        port wasteSide : FluidOutPort;
        port mechanicalState : MechanicalSignalPort;

        action def SlamShut {
            in triggerVelocity : FlowVelocity;
            in currentOpen : Boolean;
            out newOpen : Boolean;
        }
    }

    part def CheckValve {
        attribute isOpen : Boolean = false;
        attribute crackingPressure : HydraulicPressure = 150.0 [kPa];
        attribute maxArea : ValveOpeningArea = 2.0e-3 [m^2];
        port driveSide : BidirectionalFluidPort;
        port chamberSide : BidirectionalFluidPort;
        port mechanicalState : MechanicalSignalPort;

        action def OpenOnSpike {
            in drivePressure : HydraulicPressure;
            in chamberPressure : HydraulicPressure;
            out open : Boolean;
        }
    }

    part def AirChamber {
        attribute initialAirVolume : AirVolume = 2.0 [L];
        attribute currentAirVolume : AirVolume;
        attribute currentPressure : HydraulicPressure;
        attribute maxOperatingPressure : HydraulicPressure = 400.0 [kPa];
        attribute storedWaterVolume : WaterVolume;
        port inlet : BidirectionalFluidPort;
        port outlet : FluidOutPort;

        action def CompressAir {
            in incomingWaterVolume : WaterVolume;
            in currentVol : AirVolume;
            in currentPres : HydraulicPressure;
            out newVolume : AirVolume;
            out newPressure : HydraulicPressure;
        }

        action def ExpandAir {
            in currentVol : AirVolume;
            in currentPres : HydraulicPressure;
            out deliveredVolume : WaterVolume;
            out newVolume : AirVolume;
            out newPressure : HydraulicPressure;
        }
    }

    part def DeliveryPipe {
        attribute length : PipeLength = 35.0 [m];
        attribute diameter : PipeDiameter = 20.0 [mm];
        attribute liftHeight : ElevationHead = 30.0 [m];
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        attribute flowRate : PipeFlowRate;
    }

    part def DeliveryReservoir {
        attribute elevation : ElevationHead = 30.0 [m];
        attribute capacity : WaterVolume = 1000.0 [L];
        attribute currentVolume : WaterVolume;
        port inlet : FluidInPort;
    }

    // ---------- Pump Assembly ----------
    part def RamPump {
        attribute operatesWithoutExternalPower : Boolean = true;
        attribute cyclePeriod : CyclePeriod;
        attribute deliveryFlowRate : PipeFlowRate;
        attribute deliveryHead : ElevationHead;
        attribute peakPressure : HydraulicPressure;

        port sourceConnection : FluidInPort;
        port wasteOutlet : FluidOutPort;
        port deliveryConnection : FluidOutPort;

        part waterSource : WaterSource {
            attribute elevation = 2.0 [m];
        }

        part drivePipe : DrivePipe {
            attribute length = 10.0 [m];
            attribute diameter = 40.0 [mm];
        }

        part impulseValve : ImpulseValve {
            attribute thresholdVelocity = 1.5 [m/s];
        }

        part checkValve : CheckValve {
            attribute crackingPressure = 150.0 [kPa];
        }

        part airChamber : AirChamber {
            attribute initialAirVolume = 2.0 [L];
        }

        part deliveryPipe : DeliveryPipe {
            attribute length = 35.0 [m];
            attribute diameter = 20.0 [mm];
            attribute liftHeight = 30.0 [m];
        }

        part deliveryReservoir : DeliveryReservoir {
            attribute elevation = 30.0 [m];
            attribute capacity = 1000.0 [L];
        }

        // Connections
        connection waterSourceToDrivePipe connect waterSource.fluidOut to drivePipe.inlet;
        connection drivePipeToImpulseValve connect drivePipe.outlet to impulseValve.driveSide;
        connection impulseValveToWaste connect impulseValve.wasteSide to wasteOutlet;
        connection impulseValveToCheckValve connect impulseValve.driveSide to checkValve.driveSide;
        connection checkValveToAirChamber connect checkValve.chamberSide to airChamber.inlet;
        connection airChamberToDeliveryPipe connect airChamber.outlet to deliveryPipe.inlet;
        connection deliveryPipeToReservoir connect deliveryPipe.outlet to deliveryReservoir.inlet;

        // ---------- State Machine ----------
        state def PumpCycle {
            entry action { 
                drivePipe.flowVelocity := 0.0 [m/s];
                impulseValve.isOpen := true;
                checkValve.isOpen := false;
            }

            state AccelerationPhase {
                entry action {
                    impulseValve.isOpen := true;
                    checkValve.isOpen := false;
                }
                do action AccelerateWaterColumn {
                    // Water accelerates down drive pipe, exits via impulse valve
                    while drivePipe.flowVelocity < impulseValve.thresholdVelocity {
                        drivePipe.flowVelocity := drivePipe.flowVelocity + 0.1 [m/s];
                    }
                }
                transition to PressureSpikePhase
                    when drivePipe.flowVelocity >= impulseValve.thresholdVelocity;
            }

            state PressureSpikePhase {
                entry action {
                    impulseValve.isOpen := false;
                    // Water hammer pressure spike
                    peakPressure := 350.0 [kPa];
                }
                do action GenerateWaterHammer {
                    // Sudden stop of water column creates pressure spike
                    drivePipe.flowVelocity := 0.0 [m/s];
                }
                transition to CompressionPhase
                    when peakPressure >= checkValve.crackingPressure;
            }

            state CompressionPhase {
                entry action {
                    checkValve.isOpen := true;
                }
                do action PushWaterIntoChamber {
                    // High pressure forces water through check valve into air chamber
                    airChamber.CompressAir(
                        incomingWaterVolume := 0.05 [L],
                        currentVol := airChamber.currentAirVolume,
                        currentPres := airChamber.currentPressure
                    );
                }
                transition to DeliveryPhase
                    when airChamber.currentPressure >= 200.0 [kPa]
                        and peakPressure < checkValve.crackingPressure;
            }

            state DeliveryPhase {
                entry action {
                    checkValve.isOpen := false;
                }
                do action DeliverWater {
                    // Compressed air expands, pushing water up delivery pipe
                    airChamber.ExpandAir(
                        currentVol := airChamber.currentAirVolume,
                        currentPres := airChamber.currentPressure
                    );
                    deliveryPipe.flowRate := 0.5 [L/min];
                    deliveryReservoir.currentVolume := deliveryReservoir.currentVolume + 0.05 [L];
                }
                transition to ResetPhase
                    when airChamber.currentPressure <= 110.0 [kPa];
            }

            state ResetPhase {
                entry action {
                    // Pressure in drive pipe drops, impulse valve reopens
                    impulseValve.isOpen := true;
                    checkValve.isOpen := false;
                }
                do action ResetCycle {
                    drivePipe.flowVelocity := 0.0 [m/s];
                    cyclePeriod := 1.5 [s];
                }
                transition to AccelerationPhase
                    when impulseValve.isOpen = true;
            }
        }

        part behavior : PumpCycle;

        // ---------- Requirements Satisfaction ----------
        satisfy PumpingRequirement {
            subject = this;
        }
        satisfy SelfOperationRequirement {
            subject = this;
        }
    }

    // ---------- Top-level Context ----------
    part HydraulicRamPumpSystem : RamPump {
        attribute installationDate : String = "2024-01-01";
        attribute location : String = "remote site";
    }
}
