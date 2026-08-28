package BakriBalloonTamponadeSystem {

    import ScalarFunctions::*;

    // =====================================================
    // VALUE TYPES AND UNITS
    // =====================================================

    value type Volume :> Real {
        unit mL;
    }

    value type Pressure :> Real {
        unit mmHg;
    }

    value type FlowRate :> Real {
        unit mL_per_min;
    }

    value type Length :> Real {
        unit mm;
    }

    value type Temperature :> Real {
        unit degC;
    }

    unit mL;
    unit L = 1000 * mL;
    unit mmHg;
    unit kPa;
    unit mL_per_min;
    unit mm;
    unit degC;

    // =====================================================
    // ITEM DEFINITIONS
    // =====================================================

    item def SalineSolution {
        attribute concentration : String = "0.9% NaCl";
        attribute volume : Volume;
        attribute temperature : Temperature;
        attribute isSterile : Boolean = true;
    }

    item def Blood {
        attribute volume : Volume;
        attribute flowRate : FlowRate;
        attribute colorIndicator : String;
    }

    // =====================================================
    // PORT DEFINITIONS
    // =====================================================

    port def FluidOutPort {
        out item fluid : SalineSolution;
    }

    port def FluidInPort {
        in item fluid : SalineSolution;
    }

    port def BalloonFluidInPort {
        in item fluid : SalineSolution;
        out attribute currentVolume : Volume;
        out attribute currentPressure : Pressure;
    }

    port def DrainageOutPort {
        out item blood : Blood;
        out attribute volume : Volume;
        out attribute flowRate : FlowRate;
    }

    port def DrainageInPort {
        in item blood : Blood;
        out attribute collectedVolume : Volume;
    }

    port def PressureOutPort {
        out attribute pressure : Pressure;
    }

    port def PressureInPort {
        in attribute pressure : Pressure;
    }

    // =====================================================
    // CONNECTION DEFINITIONS
    // =====================================================

    connection def FluidConnection {
        end source : FluidOutPort;
        end target : FluidInPort;
        flow : SalineSolution;
    }

    connection def BalloonFluidConnection {
        end source : FluidOutPort;
        end target : BalloonFluidInPort;
        flow : SalineSolution;
    }

    connection def DrainageConnection {
        end source : DrainageOutPort;
        end target : DrainageInPort;
        flow : Blood;
    }

    connection def PressureConnection {
        end source : PressureOutPort;
        end target : PressureInPort;
    }

    // =====================================================
    // PART DEFINITIONS
    // =====================================================

    part def BakriBalloonTamponadeSystem {
        // System-level attributes
        attribute maxBalloonVolume : Volume = 500 [mL];
        attribute minEffectivePressure : Pressure = 30 [mmHg];
        attribute maxSafePressure : Pressure = 200 [mmHg];
        attribute catheterLength : Length = 600 [mm];
        attribute targetFillVolume : Volume = 250 [mL];
        attribute minFillVolume : Volume = 50 [mL];
        attribute maintenanceDurationHours : Real = 24;
        attribute isSterile : Boolean = true;

        // Sub-parts
        part balloon : SiliconeBalloon;
        part catheter : MultiLumenCatheter;
        part pressureGauge : PressureGauge;
        part drainageBag : DrainageBag;
        part syringe : Syringe;
        part valve : OneWayValve;

        // Connections between sub-parts
        connection : FluidConnection
            connect syringe.injectionPort to catheter.inflationLumenPort;

        connection : BalloonFluidConnection
            connect catheter.balloonInflationPort to balloon.inflationPort;

        connection : PressureConnection
            connect balloon.pressurePort to pressureGauge.sensorPort;

        connection : DrainageConnection
            connect catheter.drainageLumenPort to drainageBag.inletPort;

        // Internal bindings
        bind pressureGauge.currentReading = balloon.currentPressure;
        bind drainageBag.currentVolume = drainageBag.collectedVolume;

        // State machine for clinical procedure
        state machine TamponadeProcedure {
            attribute balloonInserted : Boolean = false;
            attribute hemorrhageControlled : Boolean = false;
            attribute drainageFlowDetected : Boolean = false;
            attribute inflationComplete : Boolean = false;
            attribute pressureWithinSafeRange : Boolean = true;

            state Insertion {
                entry action insertCatheter;
            }
            state Inflation {
                entry action inflateBalloon;
            }
            state TamponadeMaintenance {
                entry action maintainTamponade;
            }
            state BleedingAssessment {
                entry action assessBleeding;
            }
            state VolumeAdjustment {
                entry action adjustBalloonVolume;
            }
            state Deflation {
                entry action deflateBalloon;
            }
            state Removal {
                entry action removeCatheter;
            }

            transition from Insertion to Inflation
                when balloonInserted == true;

            transition from Inflation to TamponadeMaintenance
                when balloon.currentVolume >= minFillVolume;

            transition from TamponadeMaintenance to BleedingAssessment;

            transition from BleedingAssessment to VolumeAdjustment
                when drainageFlowDetected == true;

            transition from VolumeAdjustment to TamponadeMaintenance;

            transition from BleedingAssessment to Deflation
                when hemorrhageControlled == true;

            transition from Deflation to Removal
                when balloon.currentVolume == 0 [mL];
        }

        // Action definitions for state entries
        action def insertCatheter {
            doc "Insert the catheter with deflated balloon into the patient's uterus.";
        }

        action def inflateBalloon {
            doc "Gradually inflate the balloon with sterile saline solution using the 60 mL syringe.";
            in item fluid : SalineSolution;
        }

        action def maintainTamponade {
            doc "Maintain balloon pressure at a safe but effective level to compress bleeding blood vessels.";
        }

        action def assessBleeding {
            doc "Monitor drainage bag for ongoing blood loss to assess treatment effectiveness.";
        }

        action def adjustBalloonVolume {
            doc "Adjust balloon volume if bleeding continues after initial inflation.";
            in attribute deltaVolume : Volume;
        }

        action def deflateBalloon {
            doc "Controlled deflation of the balloon prior to removal.";
            out item fluid : SalineSolution;
        }

        action def removeCatheter {
            doc "Safely remove the entire catheter after hemorrhage is confirmed under control.";
        }

        // Requirement satisfaction
        satisfy TamponadeSystemRequirement;
        satisfy SafetyPressureRequirement;
        satisfy VolumeAdjustmentRequirement;
        satisfy DeflationRemovalRequirement;
    }

    part def SiliconeBalloon {
        attribute maxCapacity : Volume = 500 [mL];
        attribute currentVolume : Volume;
        attribute currentPressure : Pressure;
        attribute material : String = "Soft Medical Silicone";
        attribute isSterile : Boolean = true;
        attribute isDeflated : Boolean = true;

        port inflationPort : BalloonFluidInPort;
        port pressurePort : PressureOutPort;

        action def Inflate {
            doc "Inflate the balloon by injecting sterile saline solution.";
            in item fluid : SalineSolution;
        }

        action def Deflate {
            doc "Deflate the balloon by withdrawing saline solution.";
            out item fluid : SalineSolution;
        }

        action def AdjustVolume {
            doc "Adjust the balloon volume by adding or removing saline.";
            in attribute deltaVolume : Volume;
        }

        action def ComputePressure {
            in attribute volume : Volume;
            out attribute pressure : Pressure;
        }

        satisfy BalloonCapacityRequirement;
    }

    part def MultiLumenCatheter {
        attribute length : Length = 600 [mm];
        attribute outerDiameter : Length;
        attribute material : String = "Medical-grade flexible polymer";
        attribute numLumens : Integer = 3;
        attribute isFlexible : Boolean = true;

        port inflationLumenPort : FluidInPort;
        port drainageLumenPort : DrainageOutPort;
        port balloonInflationPort : FluidOutPort;

        part inflationLumen : CatheterLumen {
            attribute function : String = "Balloon inflation channel";
            attribute innerDiameter : Length = 3 [mm];
        }

        part drainageLumen : CatheterLumen {
            attribute function : String = "Central drainage channel";
            attribute innerDiameter : Length = 8 [mm];
        }

        part monitoringLumen : CatheterLumen {
            attribute function : String = "Pressure monitoring channel";
            attribute innerDiameter : Length = 2 [mm];
        }

        action def TransmitFluid {
            doc "Transmit saline solution from the inflation port through the inflation lumen to the balloon.";
            in item fluid : SalineSolution;
            out item fluidOut : SalineSolution;
        }

        action def DrainBlood {
            doc "Drain blood from above the balloon through the central drainage channel.";
            out item bloodOut : Blood;
        }

        satisfy CatheterFlexibilityRequirement;
        satisfy DrainageChannelRequirement;
        satisfy InflationPortRequirement;
    }

    part def CatheterLumen {
        attribute function : String;
        attribute innerDiameter : Length;
        attribute length : Length;
        attribute isPatent : Boolean = true;
    }

    part def PressureGauge {
        attribute measurementRangeMin : Pressure = 0 [mmHg];
        attribute measurementRangeMax : Pressure = 300 [mmHg];
        attribute accuracy : Pressure = 5 [mmHg];
        attribute currentReading : Pressure;
        attribute isDigital : Boolean = true;
        attribute isCalibrated : Boolean = true;

        port sensorPort : PressureInPort;

        action def MeasurePressure {
            doc "Measure and display the current balloon pressure.";
            in attribute balloonPressure : Pressure;
            out attribute reading : Pressure;
        }

        action def VerifySafePressure {
            doc "Verify that the measured pressure is within safe limits.";
            in attribute pressure : Pressure;
            out attribute isSafe : Boolean;
        }

        satisfy PressureMonitoringRequirement;
    }

    part def DrainageBag {
        attribute capacity : Volume = 2000 [mL];
        attribute currentVolume : Volume;
        attribute collectedVolume : Volume;
        attribute graduationInterval : Volume = 50 [mL];
        attribute material : String = "Sterile graduated collection bag";
        attribute isSterile : Boolean = true;

        port inletPort : DrainageInPort;

        action def Collect {
            doc "Collect blood drained from the uterus above the balloon.";
            in item blood : Blood;
        }

        action def Measure {
            doc "Measure the total volume of blood collected in the drainage bag.";
            out attribute measuredVolume : Volume;
        }

        action def AssessBleedingStatus {
            doc "Assess whether bleeding has stopped based on drainage volume.";
            in attribute volume : Volume;
            out attribute bleedingStopped : Boolean;
        }

        satisfy DrainageMonitoringRequirement;
    }

    part def Syringe {
        attribute capacity : Volume = 60 [mL];
        attribute currentVolume : Volume;
        attribute isSterile : Boolean = true;
        attribute isReusable : Boolean = false;

        port injectionPort : FluidOutPort;

        action def Fill {
            doc "Fill the syringe with sterile saline solution.";
            in item fluid : SalineSolution;
        }

        action def Inject {
            doc "Inject saline solution from the syringe into the catheter inflation port.";
            out item fluid : SalineSolution;
        }
    }

    part def OneWayValve {
        attribute allowsBackflow : Boolean = false;
        attribute material : String = "Medical-grade polymer";
        attribute isSterile : Boolean = true;

        action def PermitForwardFlow {
            in item fluid : SalineSolution;
            out item fluidOut : SalineSolution;
        }

        action def PreventBackflow {
            doc "Prevent backflow of saline from the balloon back through the inflation lumen.";
        }
    }

    // =====================================================
    // REQUIREMENT DEFINITIONS
    // =====================================================

    requirement def TamponadeSystemRequirement {
        id "BBTS-001";
        doc "The Bakri Balloon Tamponade System shall control severe postpartum hemorrhage through uterine tamponade by applying direct physical pressure to the internal walls of the uterus.";
    }

    requirement def BalloonCapacityRequirement {
        id "BBTS-002";
        doc "The silicone balloon shall hold up to 500 mL of sterile saline solution to effectively fill the uterine cavity and apply tamponade pressure.";
    }

    requirement def InflationPortRequirement {
        id "BBTS-003";
        doc "The system shall include an inflation port on the catheter compatible with a 60 mL syringe for filling the balloon with sterile saline solution.";
    }

    requirement def DrainageChannelRequirement {
        id "BBTS-004";
        doc "The catheter shall include a separate central drainage channel that allows blood from above the balloon to drain out of the body into a collection bag for continuous monitoring.";
    }

    requirement def DrainageMonitoringRequirement {
        id "BBTS-005";
        doc "The drainage bag shall allow medical staff to continuously monitor ongoing blood loss and assess whether the treatment is working, with cessation of drainage indicating hemorrhage control.";
    }

    requirement def PressureMonitoringRequirement {
        id "BBTS-006";
        doc "The system shall include a pressure gauge to monitor and maintain balloon pressure at a safe but effective level during tamponade maintenance.";
    }

    requirement def SafetyPressureRequirement {
        id "BBTS-007";
        doc "The balloon pressure shall not exceed a safe maximum pressure during inflation and maintenance to prevent uterine tissue damage.";
    }

    requirement def DeflationRemovalRequirement {
        id "BBTS-008";
        doc "The system shall allow controlled deflation of the balloon and safe removal of the entire catheter after hemorrhage is confirmed under control.";
    }

    requirement def CatheterFlexibilityRequirement {
        id "BBTS-009";
        doc "The catheter shall be long and flexible to allow insertion into the patient's uterus with the deflated balloon, with multiple internal lumens serving different functions.";
    }

    requirement def VolumeAdjustmentRequirement {
        id "BBTS-010";
        doc "The system shall allow adjustment of balloon volume if bleeding continues after initial inflation, enabling medical staff to modify the tamponade pressure as needed.";
    }

    requirement def SterilityRequirement {
        id "BBTS-011";
        doc "All components of the system that contact the patient or sterile fluids shall be sterile to prevent infection.";
    }

    requirement def MaintenanceDurationRequirement {
        id "BBTS-012";
        doc "The system shall be designed to remain in place for a clinically appropriate period after hemorrhage control is confirmed before balloon deflation and catheter removal.";
    }
}
