package RoundaboutPlayPumpSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit m;
    unit L;
    unit L_per_min;
    unit rev_per_min;
    unit N_m;
    unit W;
    unit percent;
    unit bar;
    unit kg;

    // ===== Value Types =====
    value type LengthValue :> Real { unit m; }
    value type DiameterValue :> Real { unit m; }
    value type DepthValue :> Real { unit m; }
    value type HeightValue :> Real { unit m; }
    value type VolumeValue :> Real { unit L; }
    value type FlowRateValue :> Real { unit L_per_min; }
    value type RotationalSpeedValue :> Real { unit rev_per_min; }
    value type TorqueValue :> Real { unit N_m; }
    value type EfficiencyValue :> Real { unit percent; }
    value type PressureValue :> Real { unit bar; }
    value type PowerValue :> Real { unit W; }
    value type MassValue :> Real { unit kg; }
    value type SeatCountValue :> Integer;

    // ===== Item Types =====
    item def Water;

    item def RotationalEnergy;

    // ===== Port Definitions =====
    port def RotationalPort {
        out speed : RotationalSpeedValue;
        out torque : TorqueValue;
    }

    port def FluidPort {
        out flowRate : FlowRateValue;
        out pressure : PressureValue;
    }

    port def ControlPort {
        out active : Boolean;
    }

    // ===== Part Definitions =====

    part def ChildrensRoundabout {
        attribute diameter : DiameterValue = 3.5 [m];
        attribute seatCount : SeatCountValue = 8;
        attribute maxRotationalSpeed : RotationalSpeedValue = 30 [rev_per_min];
        attribute minOperationalSpeed : RotationalSpeedValue = 5 [rev_per_min];
        attribute isSpinning : Boolean = false;
        attribute currentSpeed : RotationalSpeedValue = 0 [rev_per_min];
        attribute platformMass : MassValue = 500 [kg];

        port rotationalOutput : RotationalPort;
        port controlOutput : ControlPort;

        action def Spin {
            in childrenCount : SeatCountValue;
            out speed : RotationalSpeedValue;
            out torque : TorqueValue;
        }

        action def Decelerate {
            out speed : RotationalSpeedValue;
        }
    }

    part def PositiveDisplacementPump {
        attribute efficiency : EfficiencyValue = 70 [percent];
        attribute maxLiftDepth : DepthValue = 40 [m];
        attribute ratedFlowRate : FlowRateValue = 100 [L_per_min];
        attribute displacementPerRev : VolumeValue = 0.5 [L];
        attribute isActive : Boolean = false;
        attribute inputPower : PowerValue = 0 [W];
        attribute outputPressure : PressureValue = 4.0 [bar];

        port rotationalInput : RotationalPort;
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;

        action def PumpWater {
            in inputSpeed : RotationalSpeedValue;
            in inputTorque : TorqueValue;
            in suctionFlow : FlowRateValue;
            out dischargeFlow : FlowRateValue;
            out dischargePressure : PressureValue;
        }

        action def Idle {
            out dischargeFlow : FlowRateValue;
        }
    }

    part def WaterSource {
        attribute boreholeDepth : DepthValue = 40 [m];
        attribute staticWaterLevel : DepthValue = 35 [m];
        attribute waterAvailable : Boolean = true;
        attribute rechargeRate : FlowRateValue = 20 [L_per_min];

        port supplyPort : FluidPort;
    }

    part def RisingMainPipe {
        attribute material : String = "PVC";
        attribute length : LengthValue = 40 [m];
        attribute innerDiameter : DiameterValue = 0.05 [m];
        attribute maxPressure : PressureValue = 6.0 [bar];

        port inletPort : FluidPort;
        port outletPort : FluidPort;
    }

    part def DeliveryPipe {
        attribute material : String = "PVC";
        attribute length : LengthValue = 10 [m];
        attribute innerDiameter : DiameterValue = 0.05 [m];
        attribute maxPressure : PressureValue = 4.0 [bar];

        port inletPort : FluidPort;
        port outletPort : FluidPort;
    }

    part def StorageTank {
        attribute capacity : VolumeValue = 2500 [L];
        attribute elevationHeight : HeightValue = 7 [m];
        attribute currentVolume : VolumeValue = 0 [L];
        attribute inletFlowRate : FlowRateValue = 0 [L_per_min];
        attribute outletFlowRate : FlowRateValue = 0 [L_per_min];
        attribute material : String = "Polyethylene";

        port inletPort : FluidPort;
        port outletPort : FluidPort;

        state def TankStates {
            entry; then Empty;

            state Empty {
                entry action {
                    currentVolume = 0 [L];
                }
            }

            state Filling {
                entry action {
                    /* Tank is receiving water from pump */
                }
            }

            state Full {
                entry action {
                    currentVolume = capacity;
                }
            }

            state Dispensing {
                entry action {
                    /* Community members drawing water */
                }
            }

            transition Empty_to_Filling
                first Empty
                then Filling
                if inletFlowRate > 0 [L_per_min];

            transition Filling_to_Full
                first Filling
                then Full
                if currentVolume >= capacity;

            transition Full_to_Dispensing
                first Full
                then Dispensing
                if outletFlowRate > 0 [L_per_min];

            transition Dispensing_to_Filling
                first Dispensing
                then Filling
                if inletFlowRate > 0 [L_per_min] and currentVolume < capacity;

            transition Dispensing_to_Empty
                first Dispensing
                then Empty
                if currentVolume <= 0 [L];

            transition Filling_to_Dispensing
                first Filling
                then Dispensing
                if outletFlowRate > 0 [L_per_min] and currentVolume < capacity;

            transition Full_to_Filling
                first Full
                then Filling
                if outletFlowRate > 0 [L_per_min] and inletFlowRate > 0 [L_per_min];
        }

        exhibit TankStates;
    }

    // ===== System Definition =====

    part def RoundaboutPlayPump {
        attribute systemActive : Boolean = false;
        attribute totalWaterPumped : VolumeValue = 0 [L];

        part roundabout : ChildrensRoundabout;
        part pump : PositiveDisplacementPump;
        part waterSource : WaterSource;
        part risingMain : RisingMainPipe;
        part deliveryPipe : DeliveryPipe;
        part storageTank : StorageTank;

        connection roundaboutToPump connect roundabout.rotationalOutput to pump.rotationalInput;
        connection sourceToRisingMain connect waterSource.supplyPort to risingMain.inletPort;
        connection risingMainToPump connect risingMain.outletPort to pump.suctionPort;
        connection pumpToDelivery connect pump.dischargePort to deliveryPipe.inletPort;
        connection deliveryToTank connect deliveryPipe.outletPort to storageTank.inletPort;

        flow of Water from waterSource.supplyPort to risingMain.inletPort;
        flow of Water from risingMain.outletPort to pump.suctionPort;
        flow of Water from pump.dischargePort to deliveryPipe.inletPort;
        flow of Water from deliveryPipe.outletPort to storageTank.inletPort;
        flow of RotationalEnergy from roundabout.rotationalOutput to pump.rotationalInput;

        state def SystemStates {
            entry; then Standby;

            state Standby {
                entry action {
                    roundabout.isSpinning = false;
                    pump.isActive = false;
                    systemActive = false;
                }
            }

            state Active {
                entry action {
                    roundabout.isSpinning = true;
                    pump.isActive = true;
                    systemActive = true;
                }
            }

            transition Standby_to_Active
                first Standby
                then Active
                if roundabout.currentSpeed >= roundabout.minOperationalSpeed;

            transition Active_to_Standby
                first Active
                then Standby
                if roundabout.currentSpeed < roundabout.minOperationalSpeed;
        }

        exhibit SystemStates;
    }

    // ===== Requirements =====

    requirement def PumpEfficiencyRequirement {
        doc /* The positive displacement pump must achieve at least 65 percent efficiency to ensure effective water transfer. */
        subject pump : PositiveDisplacementPump;
        objective {
            pump.efficiency >= 65 [percent]
        }
    }

    requirement def WaterLiftingRequirement {
        doc /* The pump must be capable of lifting water from a depth of at least 40 meters to access the borehole water source. */
        subject pump : PositiveDisplacementPump;
        objective {
            pump.maxLiftDepth >= 40 [m]
        }
    }

    requirement def StorageCapacityRequirement {
        doc /* The storage tank must hold at least 2,500 liters of water to ensure a consistent supply for the community. */
        subject tank : StorageTank;
        objective {
            tank.capacity >= 2500 [L]
        }
    }

    requirement def TankElevationRequirement {
        doc /* The storage tank must be elevated at least 7 meters above ground level to provide adequate gravity-fed water pressure. */
        subject tank : StorageTank;
        objective {
            tank.elevationHeight >= 7 [m]
        }
    }

    requirement def RoundaboutSafetyRequirement {
        doc /* The roundabout must have a diameter of 3.5 meters and exactly 8 seats to ensure safe play for children. */
        subject roundabout : ChildrensRoundabout;
        objective {
            roundabout.diameter == 3.5 [m] and roundabout.seatCount == 8
        }
    }

    requirement def BoreholeDepthRequirement {
        doc /* The water source borehole must be 40 meters deep to access groundwater reserves. */
        subject source : WaterSource;
        objective {
            source.boreholeDepth == 40 [m]
        }
    }

    requirement def RisingMainPipeRequirement {
        doc /* The rising main pipe must be made of PVC and extend to the full borehole depth of 40 meters. */
        subject pipe : RisingMainPipe;
        objective {
            pipe.material == "PVC" and pipe.length >= 40 [m]
        }
    }

    requirement def SystemOperationRequirement {
        doc /* The system must be active and pumping water when the roundabout is in motion and remain in standby otherwise. */
        subject system : RoundaboutPlayPump;
        objective {
            system.systemActive == system.roundabout.isSpinning
        }
    }

    requirement def PumpFlowRateRequirement {
        doc /* The pump must deliver a rated flow rate of at least 100 liters per minute at operational speed. */
        subject pump : PositiveDisplacementPump;
        objective {
            pump.ratedFlowRate >= 100 [L_per_min]
        }
    }

    // ===== Verifications =====

    verification PumpEfficiencyTest {
        doc /* Measure pump efficiency under nominal operating conditions and verify it meets or exceeds 65 percent. */
        subject pump : PositiveDisplacementPump;
        objective {
            pump.efficiency >= 65 [percent]
        }
    }

    verification WaterLiftingTest {
        doc /* Verify the pump can lift water from a 40-meter borehole under operational roundabout speeds. */
        subject pump : PositiveDisplacementPump;
        objective {
            pump.maxLiftDepth >= 40 [m]
        }
    }

    verification StorageCapacityTest {
        doc /* Fill the storage tank to capacity and verify it holds at least 2,500 liters. */
        subject tank : StorageTank;
        objective {
            tank.capacity >= 2500 [L]
        }
    }

    verification TankElevationTest {
        doc /* Measure the storage tank elevation and verify it is at least 7 meters above ground level. */
        subject tank : StorageTank;
        objective {
            tank.elevationHeight >= 7 [m]
        }
    }

    verification RoundaboutSafetyTest {
        doc /* Inspect the roundabout dimensions and seat count to verify safe play conditions for children. */
        subject roundabout : ChildrensRoundabout;
        objective {
            roundabout.diameter == 3.5 [m] and roundabout.seatCount == 8
        }
    }

    verification BoreholeDepthTest {
        doc /* Measure the borehole depth and verify it reaches 40 meters to access groundwater. */
        subject source : WaterSource;
        objective {
            source.boreholeDepth == 40 [m]
        }
    }

    verification SystemOperationTest {
        doc /* Verify the system transitions between Active and Standby states based on roundabout motion. */
        subject system : RoundaboutPlayPump;
        objective {
            system.systemActive == system.roundabout.isSpinning
        }
    }

    verification PumpFlowRateTest {
        doc /* Measure the pump discharge flow rate at nominal roundabout speed and verify it meets rated capacity. */
        subject pump : PositiveDisplacementPump;
        objective {
            pump.ratedFlowRate >= 100 [L_per_min]
        }
    }
}
