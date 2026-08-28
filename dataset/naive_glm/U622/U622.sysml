package BubbleChamberSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQThermodynamics::*;

    // ---- Value Types with Units ----
    value type PressureValue :> Real { unit 'Pa'; }
    value type TemperatureValue :> Real { unit 'K'; }
    value type MagneticFluxDensityValue :> Real { unit 'T'; }
    value type TimeValue :> Real { unit 's'; }
    value type VolumeValue :> Real { unit 'm3'; }
    value type LengthValue :> Real { unit 'm'; }
    value type EnergyValue :> Real { unit 'eV'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type ParticleChargeValue :> Real { unit 'C'; }
    value type MomentumValue :> Real { unit 'kg*m/s'; }

    // ---- Items ----
    item def SuperheatedLiquid {
        attribute name: String = "LiquidHydrogen";
        attribute boilingPoint: TemperatureValue = 20.3;
        attribute currentTemperature: TemperatureValue;
        attribute currentPressure: PressureValue;
    }
    item def ChargedParticle {
        attribute charge: ParticleChargeValue;
        attribute momentum: MomentumValue;
        attribute energy: EnergyValue;
    }
    item def BubbleTrack {
        attribute trackId: Integer;
        attribute curvatureRadius: LengthValue;
        attribute length: LengthValue;
    }
    item def ImageData {
        attribute imageId: Integer;
        attribute timestamp: TimeValue;
        attribute stereoscopic: Boolean = true;
    }
    item def LightFlash {
        attribute intensity: Real;
        attribute duration: TimeValue;
    }
    item def PressureCommand {
        attribute commandType: String;
    }
    item def TriggerSignal {
        attribute source: String;
    }
    item def MagneticField {
        attribute strength: MagneticFluxDensityValue;
        attribute uniformity: Real;
    }

    // ---- Port Definitions ----
    port def LiquidSupplyPort {
        out item liquid: SuperheatedLiquid;
        in attribute pressureFeedback: PressureValue;
        in attribute temperatureFeedback: TemperatureValue;
    }
    port def ParticleEntryPort {
        in item particle: ChargedParticle;
    }
    port def PressureControlPort {
        in item command: PressureCommand;
        out attribute chamberPressure: PressureValue;
    }
    port def MagneticFieldPort {
        out item field: MagneticField;
    }
    port def IlluminationPort {
        in item trigger: TriggerSignal;
        out item flash: LightFlash;
    }
    port def ImagingPort {
        in item trigger: TriggerSignal;
        in item track: BubbleTrack;
        out item image: ImageData;
    }
    port def DataOutputPort {
        out item image: ImageData;
    }

    // ---- Part Definitions ----

    part def ChamberVessel {
        attribute vesselVolume: VolumeValue = 0.05;
        attribute nominalTemperature: TemperatureValue = 20.0;
        attribute nominalPressure: PressureValue = 5.0e5;
        attribute expansionPressure: PressureValue = 1.5e5;
        attribute wallThickness: LengthValue = 0.02;

        port liquidSupply: LiquidSupplyPort;
        port particleEntry: ParticleEntryPort;
        port pressureControl: PressureControlPort;
        port imagingOutput: ImagingPort;

        part containedLiquid: SuperheatedLiquid {
            attribute currentTemperature := nominalTemperature;
            attribute currentPressure := nominalPressure;
        }

        attribute formedTrack: BubbleTrack;

        exhibit state ChamberStateBehavior {
            state Stable {
                entry action { 
                    containedLiquid.currentPressure = nominalPressure;
                    containedLiquid.currentTemperature = nominalTemperature;
                }
            }
            state Expanding {
                entry action {
                    containedLiquid.currentPressure = expansionPressure;
                }
            }
            state BubbleFormation {
                entry action {
                    // Bubbles form along particle ionization trail
                }
            }
            state ImagingReady;
            state Recompressing {
                entry action {
                    containedLiquid.currentPressure = nominalPressure;
                }
            }

            transition from Stable to Expanding 
                when pressureControl.command.commandType == "Drop";
            transition from Expanding to BubbleFormation 
                when particleEntry.particle != null;
            transition from BubbleFormation to ImagingReady 
                after 0.001 [s];
            transition from ImagingReady to Recompressing 
                when pressureControl.command.commandType == "Rise";
            transition from Recompressing to Stable 
                after 0.5 [s];
        }
    }

    part def LiquidSupplySystem {
        attribute targetTemperature: TemperatureValue = 20.0;
        attribute targetPressure: PressureValue = 5.0e5;
        attribute toleranceTemperature: TemperatureValue = 0.1;
        attribute tolerancePressure: PressureValue = 1.0e3;

        port supplyOutput: LiquidSupplyPort;
        port pressureControl: PressureControlPort;

        part heater {
            attribute power: Real = 50.0;
            attribute status: String = "Off";
        }
        part pump {
            attribute flowRate: Real = 0.001;
            attribute status: String = "Idle";
        }
        part temperatureSensor {
            attribute reading: TemperatureValue;
        }
        part pressureSensor {
            attribute reading: PressureValue;
        }

        exhibit action def RegulateLiquid :> Action {
            in liquidState: SuperheatedLiquid;
            out regulatedLiquid: SuperheatedLiquid;
            
            perform action senseTemperature;
            perform action sensePressure;
            perform action adjustHeater;
            perform action adjustPump;
            
            then senseTemperature;
            then sensePressure;
            then if (liquidState.currentTemperature > targetTemperature + toleranceTemperature) {
                adjustHeater;
            }
            then if (liquidState.currentPressure < targetPressure - tolerancePressure) {
                adjustPump;
            }
        }
    }

    part def ExpansionMechanism {
        attribute pistonDiameter: LengthValue = 0.1;
        attribute pistonStroke: LengthValue = 0.05;
        attribute expansionTime: TimeValue = 0.01;
        attribute recompressTime: TimeValue = 0.1;
        attribute position: LengthValue = 0.0;

        port pressureControl: PressureControlPort;
        port triggerInput: IlluminationPort;

        exhibit state ExpansionStateBehavior {
            state Retracted;
            state Expanding {
                entry action { position = pistonStroke; }
            }
            state Expanded;
            state Recompressing {
                entry action { position = 0.0; }
            }

            transition from Retracted to Expanding 
                when pressureControl.command.commandType == "Drop";
            transition from Expanding to Expanded 
                after expansionTime;
            transition from Expanded to Recompressing 
                when pressureControl.command.commandType == "Rise";
            transition from Recompressing to Retracted 
                after recompressTime;
        }

        action def ActuatePiston :> Action {
            in command: PressureCommand;
            out newPosition: LengthValue;
            
            if command.commandType == "Drop" {
                newPosition = pistonStroke;
            } else if command.commandType == "Rise" {
                newPosition = 0.0;
            }
        }
    }

    part def MagneticFieldSystem {
        attribute fieldStrength: MagneticFluxDensityValue = 1.5;
        attribute uniformity: Real = 0.999;
        attribute coilCurrent: CurrentValue = 500.0;
        attribute coilVoltage: VoltageValue = 200.0;

        port fieldOutput: MagneticFieldPort;

        part magnetCoil {
            attribute turns: Integer = 1000;
            attribute current: CurrentValue := coilCurrent;
        }
        part powerSupply {
            attribute outputVoltage: VoltageValue := coilVoltage;
            attribute status: String = "On";
        }
        part fieldSensor {
            attribute measuredStrength: MagneticFluxDensityValue;
        }

        action def GenerateField :> Action {
            out field: MagneticField;
            field.strength = fieldStrength;
            field.uniformity = uniformity;
        }
    }

    part def IlluminationSystem {
        attribute flashIntensity: Real = 1.0e6;
        attribute flashDuration: TimeValue = 0.0001;
        attribute lampType: String = "XenonFlash";

        port illuminationOutput: IlluminationPort;

        part flashLamp {
            attribute status: String = "Standby";
        }
        part capacitorBank {
            attribute chargeVoltage: VoltageValue = 1000.0;
            attribute storedEnergy: EnergyValue = 100.0;
        }

        action def FireFlash :> Action {
            in trigger: TriggerSignal;
            out flash: LightFlash;
            flash.intensity = flashIntensity;
            flash.duration = flashDuration;
        }
    }

    part def ImagingSystem {
        attribute cameraCount: Integer = 3;
        attribute resolution: Integer = 4096;
        attribute frameRate: FrequencyValue = 10000.0;
        attribute stereoscopic: Boolean = true;

        port imagingInput: ImagingPort;
        port dataOutput: DataOutputPort;

        part cameras[3] {
            attribute sensorType: String = "CCD";
            attribute exposureTime: TimeValue = 0.00005;
        }
        part imageProcessor {
            attribute bufferDepth: Integer = 64;
        }
        part storageUnit {
            attribute capacityGB: Integer = 2048;
        }

        action def CaptureImage :> Action {
            in trigger: TriggerSignal;
            in track: BubbleTrack;
            out image: ImageData;
            
            perform action synchronizeCameras;
            perform action exposeSensors;
            perform action readoutData;
            perform action storeImage;
            
            then synchronizeCameras;
            then exposeSensors;
            then readoutData;
            then storeImage;
        }
    }

    part def ControlSystem {
        attribute cyclePeriod: TimeValue = 1.0;
        attribute status: String = "Idle";

        port pressureCommandOut: PressureControlPort;
        port illuminationTriggerOut: IlluminationPort;
        port imagingTriggerOut: ImagingPort;
        port particleSensorIn: ParticleEntryPort;

        exhibit state ControlStateBehavior {
            state Idle;
            state WaitingForParticle;
            state TriggeringExpansion;
            state TriggeringImaging;
            state TriggeringRecompression;

            transition from Idle to WaitingForParticle 
                when status == "Active";
            transition from WaitingForParticle to TriggeringExpansion 
                when particleSensorIn.particle != null;
            transition from TriggeringExpansion to TriggeringImaging 
                after 0.005 [s];
            transition from TriggeringImaging to TriggeringRecompression 
                after 0.001 [s];
            transition from TriggeringRecompression to WaitingForParticle 
                after 0.5 [s];
            transition from WaitingForParticle to Idle 
                when status == "Shutdown";
        }

        action def CoordinateCycle :> Action {
            in particle: ChargedParticle;
            out pressureCmd: PressureCommand;
            out illumTrigger: TriggerSignal;
            out imgTrigger: TriggerSignal;
            
            pressureCmd.commandType = "Drop";
            then illumTrigger.source = "ExpansionComplete";
            then imgTrigger.source = "IlluminationFired";
            then pressureCmd.commandType = "Rise";
        }
    }

    // ---- Top-level System ----
    part def BubbleChamber {
        attribute systemId: String = "BC-001";
        attribute operationalStatus: String = "Offline";

        part chamber: ChamberVessel;
        part liquidSupply: LiquidSupplySystem;
        part expansionMechanism: ExpansionMechanism;
        part magneticField: MagneticFieldSystem;
        part illumination: IlluminationSystem;
        part imaging: ImagingSystem;
        part controller: ControlSystem;

        connection liquidSupply.supplyOutput to chamber.liquidSupply;
        connection expansionMechanism.pressureControl to chamber.pressureControl;
        connection controller.pressureCommandOut to expansionMechanism.pressureControl;
        connection controller.illuminationTriggerOut to illumination.illuminationOutput;
        connection controller.imagingTriggerOut to imaging.imagingInput;
        connection illumination.illuminationOutput.flash to imaging.imagingInput.trigger;
        connection chamber.imagingOutput.track to imaging.imagingInput.track;
        connection magneticField.fieldOutput.field to chamber.particleEntry;
        connection imaging.dataOutput.image to chamber.imagingOutput.image;
        connection controller.particleSensorIn.particle to chamber.particleEntry.particle;
    }

    // ---- Requirements ----
    requirement def DetectChargedParticles {
        attribute id: String = "REQ-001";
        doc /* The system shall detect and visualize trajectories of subatomic charged particles. */
        subject bubbleChamber: BubbleChamber;
        objective {
            verify bubbleChamber.chamber.containedLiquid.currentPressure == bubbleChamber.chamber.expansionPressure
            implies bubbleChamber.chamber.formedTrack != null;
        }
    }

    requirement def MaintainSuperheatedState {
        attribute id: String = "REQ-002";
        doc /* The liquid supply system shall maintain the liquid in a superheated state just below its boiling point. */
        subject liquidSupply: LiquidSupplySystem;
        attribute maxTempDeviation: TemperatureValue = 0.1;
        attribute maxPressureDeviation: PressureValue = 1.0e3;
        objective {
            verify abs(liquidSupply.targetTemperature - liquidSupply.supplyOutput.liquid.currentTemperature) <= maxTempDeviation
            and abs(liquidSupply.targetPressure - liquidSupply.supplyOutput.liquid.currentPressure) <= maxPressureDeviation;
        }
    }

    requirement def RapidPressureDrop {
        attribute id: String = "REQ-003";
        doc /* The expansion mechanism shall drop chamber pressure within 10 milliseconds to induce bubble formation readiness. */
        subject expansion: ExpansionMechanism;
        attribute maxExpansionTime: TimeValue = 0.01;
        objective {
            verify expansion.expansionTime <= maxExpansionTime;
        }
    }

    requirement def UniformMagneticField {
        attribute id: String = "REQ-004";
        doc /* The magnetic field system shall provide a uniform field to curve charged particle trajectories. */
        subject magnet: MagneticFieldSystem;
        attribute minUniformity: Real = 0.99;
        attribute minStrength: MagneticFluxDensityValue = 1.0;
        objective {
            verify magnet.uniformity >= minUniformity
            and magnet.fieldStrength >= minStrength;
        }
    }

    requirement def StereoscopicImaging {
        attribute id: String = "REQ-005";
        doc /* The imaging system shall capture stereoscopic photographs of bubble tracks using multiple cameras. */
        subject imaging: ImagingSystem;
        attribute minCameras: Integer = 3;
        objective {
            verify imaging.cameraCount >= minCameras
            and imaging.stereoscopic == true;
        }
    }

    requirement def RapidRecompression {
        attribute id: String = "REQ-006";
        doc /* The system shall recompress the liquid after imaging to restore stable high-pressure state. */
        subject chamber: ChamberVessel;
        attribute maxRecompressTime: TimeValue = 0.5;
        objective {
            verify chamber.nominalPressure == chamber.containedLiquid.currentPressure
            after chamber.ChamberStateBehavior.Recompressing;
        }
    }

    requirement def CycleReadiness {
        attribute id: String = "REQ-007";
        doc /* The system shall return to a stable state ready to detect the next particle after each cycle. */
        subject bubbleChamber: BubbleChamber;
        objective {
            verify bubbleChamber.chamber.ChamberStateBehavior.Stable.isActive
            implies bubbleChamber.operationalStatus == "Ready";
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction satisfy DetectChargedParticles by BubbleChamber;
    satisfaction satisfy MaintainSuperheatedState by LiquidSupplySystem;
    satisfaction satisfy RapidPressureDrop by ExpansionMechanism;
    satisfaction satisfy UniformMagneticField by MagneticFieldSystem;
    satisfaction satisfy StereoscopicImaging by ImagingSystem;
    satisfaction satisfy RapidRecompression by ChamberVessel;
    satisfaction satisfy CycleReadiness by BubbleChamber;
}
