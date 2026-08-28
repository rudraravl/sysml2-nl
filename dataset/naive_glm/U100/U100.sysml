package InflatablePenileImplantSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ================================================================
    // ITEM DEFINITIONS
    // ================================================================

    item def SterileSalineSolution {
        doc { Sterile 0.9% saline working fluid for the closed hydraulic circuit }
        attribute concentration : Real = 0.009;
        attribute phLevel : Real = 7.4;
        attribute isSterile : Boolean = true;
        attribute temperature : Temperature = 310.15[K];
    }

    // ================================================================
    // VALUE TYPES (with units)
    // ================================================================

    value type HydraulicPressure :> Pressure {
        doc { Internal hydraulic pressure within the implant system }
    }

    value type FluidVolume :> Volume {
        doc { Volume of saline fluid in a component }
    }

    value type FlowRateValue :> VolumeFlowRate {
        doc { Volumetric flow rate of saline through a conduit }
    }

    value type RigidityIndex :> Real {
        doc { Rigidity ratio: 0.0 = flaccid, 1.0 = fully erect }
    }

    value type PumpStrokeVolume :> Volume {
        doc { Volume of saline transferred per pump compression }
    }

    // ================================================================
    // PORT DEFINITIONS
    // ================================================================

    port def HydraulicPort {
        doc { Bidirectional hydraulic fluid port for saline flow }
        in item salineIn : SterileSalineSolution;
        out item salineOut : SterileSalineSolution;
        attribute currentPressure : HydraulicPressure;
    }

    // ================================================================
    // FLOW DEFINITIONS
    // ================================================================

    flow def SalineFlow {
        end source : SterileSalineSolution;
        end target : SterileSalineSolution;
        attribute flowRate : FlowRateValue;
        attribute pressure : HydraulicPressure;
    }

    // ================================================================
    // INTERFACE DEFINITIONS
    // ================================================================

    interface def HydraulicConduit {
        doc { Bidirectional hydraulic conduit connecting two components }
        end endA : HydraulicPort;
        end endB : HydraulicPort;
        flow forward : SalineFlow from endA.salineOut to endB.salineIn;
        flow reverse : SalineFlow from endB.salineOut to endA.salineIn;
    }

    // ================================================================
    // REQUIREMENT DEFINITIONS
    // ================================================================

    requirement def PressureSafetyLimit {
        doc { The system must operate within safe pressure limits to prevent injury or device failure }
        attribute maxSafePressure : Pressure = 83[kPa];
        attribute minSafePressure : Pressure = 0[kPa];
        subject system : ImplantSystem;
        require constraint { system.currentPressure <= maxSafePressure; }
        require constraint { system.currentPressure >= minSafePressure; }
    }

    requirement def FluidReturnCompleteness {
        doc { The system must return nearly all fluid to the reservoir to achieve a natural flaccid state }
        attribute minReturnFraction : Real = 0.99;
        subject system : ImplantSystem;
        require constraint { system.reservoir.returnedVolume >= system.totalCylinderVolume * minReturnFraction; }
    }

    requirement def OnDemandErection {
        doc { The system must provide on-demand erectile function within a reasonable time }
        attribute maxInflationTime : Time = 1800[s];
        subject system : ImplantSystem;
        require constraint { system.inflationTime <= maxInflationTime; }
    }

    requirement def UserControlledOperation {
        doc { The entire operation must be user-controlled via manual pump and release valve }
        subject system : ImplantSystem;
        require constraint { system.pump.pumpBody.compressionRequested == true implies system.isOperational; }
        require constraint { system.pump.releaseValveActivated == true implies system.isOperational; }
    }

    // ================================================================
    // PART DEFINITIONS — Release Valve
    // ================================================================

    part def ReleaseValve {
        doc { Integrated release valve within the pump for fluid return to reservoir }

        attribute isOpen : Boolean = false;
        attribute maxFlowRate : FlowRateValue = 50[mL/s];
        attribute activationForce : Force = 5[N];

        port reservoirSidePort : HydraulicPort;
        port cylinderSidePort : HydraulicPort;

        action def open {
            doc { Open the release valve channel to allow fluid return }
            assign isOpen = true;
        }

        action def close {
            doc { Close the release valve channel after deflation }
            assign isOpen = false;
        }

        exhibit state {
            initial;
            state Closed;
            state Open;
            transition from Closed to Open when isOpen;
            transition from Open to Closed when !isOpen;
        }
    }

    // ================================================================
    // PART DEFINITIONS — Manual Pump
    // ================================================================

    part def ManualPump {
        doc { Manually compressed pump body that transfers saline from reservoir to cylinders }

        attribute strokeVolume : PumpStrokeVolume = 0.5[mL];
        attribute maxStrokeForce : Force = 25[N];
        attribute compressionCount : Integer = 0;
        attribute compressionRequested : Boolean = false;
        attribute requiredCompressions : Integer = 50;

        port intakePort : HydraulicPort;
        port outflowPort : HydraulicPort;

        action def compress {
            doc { User squeezes pump, transferring stroke volume from intake to outflow }
            assign compressionCount = compressionCount + 1;
        }

        action def reset {
            doc { Reset compression count after a complete inflation cycle }
            assign compressionCount = 0;
            assign compressionRequested = false;
        }

        exhibit state {
            initial;
            state Idle;
            state Compressing {
                do compress;
            }
            transition from Idle to Compressing when compressionRequested;
            transition from Compressing to Idle when !compressionRequested;
        }
    }

    // ================================================================
    // PART DEFINITIONS — Pump Assembly
    // ================================================================

    part def PumpAssembly {
        doc { Manual pump with integrated release valve, placed in the scrotum for easy user access }

        attribute releaseValveActivated : Boolean = false;
        attribute requiredCompressions : Integer = 50;

        part pumpBody : ManualPump;
        part releaseValve : ReleaseValve;

        port reservoirPort : HydraulicPort;
        port leftCylinderPort : HydraulicPort;
        port rightCylinderPort : HydraulicPort;

        action def compress {
            doc { Delegate compression to the pump body }
            perform pumpBody.compress;
        }

        action def activateReleaseValve {
            doc { Open the release valve to allow fluid to return from cylinders to reservoir }
            assign releaseValveActivated = true;
            perform releaseValve.open;
        }

        action def deactivateReleaseValve {
            doc { Close the release valve after deflation is complete }
            assign releaseValveActivated = false;
            perform releaseValve.close;
        }

        exhibit state {
            initial;
            state Ready;
            state Pumping {
                do compress;
            }
            state Releasing {
                do activateReleaseValve;
            }
            transition from Ready to Pumping when pumpBody.compressionRequested;
            transition from Pumping to Ready when pumpBody.compressionCount >= requiredCompressions;
            transition from Ready to Releasing when releaseValveActivated;
            transition from Releasing to Ready when !releaseValveActivated;
        }
    }

    // ================================================================
    // PART DEFINITIONS — Fluid Reservoir
    // ================================================================

    part def FluidReservoir {
        doc { Surgically implanted saline reservoir placed in the abdomen }

        attribute capacity : FluidVolume = 100[mL];
        attribute currentVolume : FluidVolume = 100[mL];
        attribute returnedVolume : FluidVolume = 0[mL];
        attribute isSupplying : Boolean = false;
        attribute isReceiving : Boolean = false;

        port hydraulicPort : HydraulicPort;

        action def dispense {
            doc { Release saline when pump creates suction during inflation }
            assign currentVolume = currentVolume - 0.5[mL];
        }

        action def receive {
            doc { Receive saline back from cylinders during deflation }
            assign currentVolume = currentVolume + 0.5[mL];
            assign returnedVolume = returnedVolume + 0.5[mL];
        }

        exhibit state {
            initial;
            state Idle;
            state Supplying {
                do dispense;
            }
            state Receiving {
                do receive;
            }
            transition from Idle to Supplying when isSupplying;
            transition from Supplying to Idle when !isSupplying;
            transition from Idle to Receiving when isReceiving;
            transition from Receiving to Idle when !isReceiving;
        }
    }

    // ================================================================
    // PART DEFINITIONS — Inflatable Cylinder
    // ================================================================

    part def InflatableCylinder {
        doc { Inflatable cylinder implanted within the penis for erection }

        attribute maxVolume : FluidVolume = 25[mL];
        attribute currentVolume : FluidVolume = 0[mL];
        attribute currentPressure : HydraulicPressure = 0[kPa];
        attribute currentRigidity : RigidityIndex = 0.0;
        attribute isFilling : Boolean = false;
        attribute isDeflating : Boolean = false;

        port hydraulicPort : HydraulicPort;

        action def inflate {
            doc { Inflate the cylinder by receiving saline through the hydraulic port }
            assign currentVolume = currentVolume + 0.5[mL];
            assign currentRigidity = currentVolume / maxVolume;
        }

        action def deflate {
            doc { Deflate the cylinder by releasing saline back toward the reservoir }
            assign currentVolume = currentVolume - 0.5[mL];
            assign currentRigidity = currentVolume / maxVolume;
        }

        exhibit state {
            initial;
            state Empty {
                entry {
                    assign currentRigidity = 0.0;
                    assign currentVolume = 0[mL];
                }
            }
            state Filling {
                do inflate;
            }
            state Inflated {
                entry {
                    assign currentRigidity = 1.0;
                }
            }
            state Deflating {
                do deflate;
            }
            transition from Empty to Filling when isFilling;
            transition from Filling to Inflated when currentVolume >= maxVolume;
            transition from Inflated to Deflating when isDeflating;
            transition from Deflating to Empty when currentVolume <= 0[mL];
        }
    }

    // ================================================================
    // PART DEFINITIONS — Implant System (top-level)
    // ================================================================

    part def ImplantSystem {
        doc { Three-component inflatable penile implant: a closed-loop hydraulic system using sterile saline. The reservoir is placed in the abdomen, the pump in the scrotum, and the two cylinders within the penis. }

        attribute totalCylinderVolume : FluidVolume = 50[mL];
        attribute currentPressure : HydraulicPressure = 0[kPa];
        attribute currentRigidity : RigidityIndex = 0.0;
        attribute inflationTime : Time = 0[s];
        attribute isOperational : Boolean = true;

        part reservoir : FluidReservoir;
        part pump : PumpAssembly;
        part leftCylinder : InflatableCylinder;
        part rightCylinder : InflatableCylinder;

        // Closed-loop hydraulic circuit connections
        connection reservoirToPump : HydraulicConduit connect reservoir.hydraulicPort to pump.reservoirPort;
        connection pumpToLeftCylinder : HydraulicConduit connect pump.leftCylinderPort to leftCylinder.hydraulicPort;
        connection pumpToRightCylinder : HydraulicConduit connect pump.rightCylinderPort to rightCylinder.hydraulicPort;

        exhibit state {
            initial;
            state Flaccid {
                doc { Natural flaccid state; cylinders empty, reservoir full }
                entry {
                    assign currentRigidity = 0.0;
                    assign pump.pumpBody.compressionCount = 0;
                    assign reservoir.isSupplying = false;
                    assign reservoir.isReceiving = false;
                    assign leftCylinder.isFilling = false;
                    assign rightCylinder.isFilling = false;
                    assign leftCylinder.isDeflating = false;
                    assign rightCylinder.isDeflating = false;
                }
            }
            state Inflating {
                doc { User manually squeezes pump; fluid transfers from reservoir to cylinders }
                entry {
                    assign reservoir.isSupplying = true;
                    assign leftCylinder.isFilling = true;
                    assign rightCylinder.isFilling = true;
                }
                do {
                    pump.compress;
                }
            }
            state Erect {
                doc { Sufficient rigidity achieved; erection maintained }
                entry {
                    assign currentRigidity = 1.0;
                    assign reservoir.isSupplying = false;
                    assign leftCylinder.isFilling = false;
                    assign rightCylinder.isFilling = false;
                    assign pump.pumpBody.compressionRequested = false;
                }
            }
            state Deflating {
                doc { Release valve activated; fluid returns from cylinders to reservoir }
                entry {
                    assign reservoir.isReceiving = true;
                    assign leftCylinder.isDeflating = true;
                    assign rightCylinder.isDeflating = true;
                }
                do {
                    pump.activateReleaseValve;
                }
            }
            transition from Flaccid to Inflating when pump.pumpBody.compressionRequested;
            transition from Inflating to Erect when currentRigidity >= 0.95;
            transition from Erect to Deflating when pump.releaseValveActivated;
            transition from Deflating to Flaccid when currentRigidity <= 0.05;
        }

        satisfy PressureSafetyLimit;
        satisfy FluidReturnCompleteness;
        satisfy OnDemandErection;
        satisfy UserControlledOperation;
    }
}
