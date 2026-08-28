package SyphonSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value def Length :> Real;
    value def Diameter :> Real;
    value def Volume :> Real;
    value def Height :> Real;
    value def Pressure :> Real;
    value def VolumetricFlowRate :> Real;
    value def CrossSectionalArea :> Real;
    value def MassDensity :> Real;
    value def GravitationalAcceleration :> Real;
    value def Duration :> Real;
    value def Velocity :> Real;
    value def Mass :> Real;

    // ===== Named Constants =====
    attribute atmosphericPressure : Pressure = 101325;
    attribute gravity : GravitationalAcceleration = 9.81;
    attribute waterDensity : MassDensity = 1000;

    // ===== Item Types =====
    item def Fluid {
        attribute density : MassDensity = waterDensity;
        attribute temperature : Real;
    }

    item def Air {
        attribute pressure : Pressure = atmosphericPressure;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        attribute flowRate : VolumetricFlowRate;
        out item fluid : Fluid;
    }

    // ===== Part Definitions =====
    part def SourceReservoir {
        attribute capacity : Volume;
        attribute currentVolume : Volume;
        attribute surfaceHeight : Height;
        attribute baseElevation : Height;
        attribute crossSectionalArea : CrossSectionalArea;
        attribute outletElevation : Height;

        port outlet : FluidPort;

        attribute isDepleted : Boolean = (currentVolume <= 0);
        attribute outletSubmerged : Boolean = (surfaceHeight > outletElevation);

        action def DrainFluid {
            in dt : Duration;
            in outflowRate : VolumetricFlowRate;
            out newVolume : Volume;
            out newSurfaceHeight : Height;
        }
    }

    part def ReceivingReservoir {
        attribute capacity : Volume;
        attribute currentVolume : Volume;
        attribute surfaceHeight : Height;
        attribute baseElevation : Height;
        attribute crossSectionalArea : CrossSectionalArea;
        attribute inletElevation : Height;

        port inlet : FluidPort;

        attribute isFull : Boolean = (currentVolume >= capacity);

        action def ReceiveFluid {
            in dt : Duration;
            in inflowRate : VolumetricFlowRate;
            out newVolume : Volume;
            out newSurfaceHeight : Height;
        }
    }

    part def SyphonTube {
        attribute totalLength : Length;
        attribute diameter : Diameter;
        attribute apexHeight : Height;
        attribute inletElevation : Height;
        attribute outletElevation : Height;
        attribute crossSectionalArea : CrossSectionalArea;
        attribute isPrimed : Boolean = false;

        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute isFilled : Boolean = isPrimed;

        action def Prime {
            in fluid : Fluid;
            out success : Boolean;
        }

        action def ComputeFlowRate {
            in sourceSurfaceHeight : Height;
            in receivingSurfaceHeight : Height;
            in tubeArea : CrossSectionalArea;
            out flowRate : VolumetricFlowRate;
        }

        action def TransferFluid {
            in dt : Duration;
            in sourceHeight : Height;
            in receivingHeight : Height;
            out transferredVolume : Volume;
            out flowRate : VolumetricFlowRate;
        }
    }

    // ===== State Machine Definition =====
    state def SyphonState {
        attribute currentFlowRate : VolumetricFlowRate;
    }

    // ===== Main System =====
    part def SyphonSystem {
        // --- Parts ---
        part sourceReservoir : SourceReservoir {
            attribute capacity = 0.05;
            attribute baseElevation = 1.0;
            attribute crossSectionalArea = 0.01;
            attribute outletElevation = 0.8;
            attribute currentVolume = 0.04;
            attribute surfaceHeight = baseElevation + (currentVolume / crossSectionalArea);
        }

        part receivingReservoir : ReceivingReservoir {
            attribute capacity = 0.05;
            attribute baseElevation = 0.0;
            attribute crossSectionalArea = 0.01;
            attribute inletElevation = 0.2;
            attribute currentVolume = 0.0;
            attribute surfaceHeight = baseElevation + (currentVolume / crossSectionalArea);
        }

        part syphonTube : SyphonTube {
            attribute totalLength = 2.0;
            attribute diameter = 0.02;
            attribute inletElevation = 0.8;
            attribute outletElevation = 0.2;
            attribute apexHeight = 1.5;
            attribute crossSectionalArea = 3.14159 * (diameter / 2) * (diameter / 2);
            attribute isPrimed = false;
        }

        // --- Connections ---
        connection sourceToTube : FluidPort connect sourceReservoir.outlet to syphonTube.inlet {
            attribute flowRate : VolumetricFlowRate;
            out item fluid : Fluid;
        }

        connection tubeToReceiving : FluidPort connect syphonTube.outlet to receivingReservoir.inlet {
            attribute flowRate : VolumetricFlowRate;
            out item fluid : Fluid;
        }

        // --- Item Flows ---
        flow of Fluid through sourceToTube;
        flow of Fluid through tubeToReceiving;

        // --- State Machine ---
        exhibit state syphonOperation : SyphonState {

            state idle {
                entry action IdleEntry {
                    syphonTube.isPrimed = false;
                    currentFlowRate = 0.0;
                }
            }

            state priming {
                entry action PrimeTube {
                    // Completely fill the tube with fluid to eliminate air pockets
                    syphonTube.isPrimed = true;
                }
            }

            state active {
                entry action ActivateFlow {
                    // Calculate flow rate using Torricelli's principle:
                    // Q = A * sqrt(2 * g * deltaH)
                    currentFlowRate = syphonTube.crossSectionalArea *
                        sqrt(2 * gravity *
                            (sourceReservoir.surfaceHeight - receivingReservoir.surfaceHeight));
                }

                do action UpdateReservoirs {
                    // Update source reservoir volume and height
                    sourceReservoir.currentVolume = sourceReservoir.currentVolume -
                        (currentFlowRate * 1.0);
                    sourceReservoir.surfaceHeight = sourceReservoir.baseElevation +
                        (sourceReservoir.currentVolume / sourceReservoir.crossSectionalArea);

                    // Update receiving reservoir volume and height
                    receivingReservoir.currentVolume = receivingReservoir.currentVolume +
                        (currentFlowRate * 1.0);
                    receivingReservoir.surfaceHeight = receivingReservoir.baseElevation +
                        (receivingReservoir.currentVolume / receivingReservoir.crossSectionalArea);
                }
            }

            state stopped {
                entry action StopFlow {
                    currentFlowRate = 0.0;
                }
            }

            // --- Transitions ---
            transition idle_to_priming
                first idle
                then priming
                if true;

            transition priming_to_active
                first priming
                then active
                if syphonTube.isPrimed;

            transition active_to_stopped_depleted
                first active
                then stopped
                if sourceReservoir.currentVolume <= 0.0;

            transition active_to_stopped_full
                first active
                then stopped
                if receivingReservoir.currentVolume >= receivingReservoir.capacity;

            transition active_to_stopped_equalized
                first active
                then stopped
                if sourceReservoir.surfaceHeight <= receivingReservoir.surfaceHeight;

            transition stopped_to_idle
                first stopped
                then idle
                if true;
        }

        // --- Requirements ---
        requirement def PassiveTransferRequirement {
            doc "The system shall passively transfer fluid from a higher reservoir to a lower one without external pumps or power."
        }

        requirement def GravityDrivenFlowRequirement {
            doc "The system shall transfer fluid using only gravitational potential energy and atmospheric pressure."
        }

        requirement def PrimingRequirement {
            doc "The syphon tube shall be completely filled with fluid to eliminate all air pockets before active transfer begins."
        }

        requirement def ContinuousFlowRequirement {
            doc "The system shall maintain continuous automatic flow as long as the source fluid level exceeds the receiving fluid level and the source outlet remains submerged."
        }

        requirement def StopConditionRequirement {
            doc "The system shall stop flow when the source reservoir is depleted, the receiving reservoir is full, or the fluid levels in both reservoirs equalize."
        }

        requirement def ApexHeightRequirement {
            doc "The syphon tube apex shall rise above the source reservoir fluid surface level while remaining below the maximum practical syphon height of approximately 10 meters for water at sea level."
        }

        requirement def TubeDimensionRequirement {
            doc "The syphon tube total length and diameter shall be selected to achieve the desired volumetric flow rate between the two reservoirs."
        }

        requirement def ReservoirCapacityRequirement {
            doc "The receiving reservoir capacity shall be sufficient to accept the total volume of fluid transferred from the source reservoir without overflow."
        }

        requirement def SourceSubmersionRequirement {
            doc "The syphon tube inlet within the source reservoir shall remain submerged below the fluid surface throughout the active transfer phase."
        }

        // --- Satisfy Relationships ---
        satisfy PassiveTransferRequirement by syphonTube;
        satisfy GravityDrivenFlowRequirement by syphonTube;
        satisfy PrimingRequirement by syphonTube;
        satisfy ContinuousFlowRequirement by syphonOperation;
        satisfy StopConditionRequirement by syphonOperation;
        satisfy ApexHeightRequirement by syphonTube;
        satisfy TubeDimensionRequirement by syphonTube;
        satisfy ReservoirCapacityRequirement by receivingReservoir;
        satisfy SourceSubmersionRequirement by sourceReservoir;

        // --- Verifications ---
        verification PassiveTransferVerification : PassiveTransferRequirement {
            doc "Verify that no pumps, motors, or external power sources are present in the system design."
        }

        verification GravityDrivenVerification : GravityDrivenFlowRequirement {
            doc "Verify that fluid flow is driven solely by the pressure differential created by gravitational head difference and atmospheric pressure on the source surface."
        }

        verification PrimingVerification : PrimingRequirement {
            doc "Verify that the syphon tube is completely filled with fluid and contains no air pockets after the priming action is executed."
        }

        verification ContinuousFlowVerification : ContinuousFlowRequirement {
            doc "Verify that flow continues automatically while source surface height exceeds receiving surface height and the source outlet remains submerged."
        }

        verification StopConditionVerification : StopConditionRequirement {
            doc "Verify that flow stops under all three conditions: source depletion, receiving reservoir full, and level equalization."
        }

        verification ApexHeightVerification : ApexHeightRequirement {
            doc "Verify that the tube apex height is above the source fluid surface level and below 10 meters for water at standard atmospheric pressure."
        }

        verification TubeDimensionVerification : TubeDimensionRequirement {
            doc "Verify that the tube length and diameter produce the expected flow rate per the Torricelli equation."
        }

        verification ReservoirCapacityVerification : ReservoirCapacityRequirement {
            doc "Verify that the receiving reservoir capacity is greater than or equal to the initial source fluid volume."
        }

        verification SourceSubmersionVerification : SourceSubmersionRequirement {
            doc "Verify that the tube inlet elevation is below the minimum source fluid surface height during active operation."
        }
    }
}
