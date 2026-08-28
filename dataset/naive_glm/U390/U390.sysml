package SpeculumModel {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types with Units ----
    attribute def Wavelength :> Real {
        :>> unit = "nm";
    }
    attribute def OpticalIntensity :> Real {
        :>> unit = "W/m^2";
    }
    attribute def Reflectance :> Real {
        :>> unit = "1";  // dimensionless ratio
    }
    attribute def SurfaceRoughness :> Real {
        :>> unit = "nm";
    }
    attribute def AngularTilt :> Real {
        :>> unit = "deg";
    }
    attribute def CoefficientOfThermalExpansion :> Real {
        :>> unit = "1/K";
    }
    attribute def Temperature :> Real {
        :>> unit = "K";
    }
    attribute def PolarizationState :> String;
    attribute def OpticalPower :> Real {
        :>> unit = "W";
    }

    // ---- Items ----
    item def LightBeam {
        attribute wavelength : Wavelength;
        attribute intensity : OpticalIntensity;
        attribute polarization : PolarizationState;
        attribute opticalPower : OpticalPower;
        attribute incidentAngle : AngularTilt;
    }

    // ---- Enumerations ----
    enum def OperationalState {
        standby = 0,
        active = 1,
        faulted = 2
    }

    enum def CoatingType {
        enhancedAluminum = 0,
        protectedSilver = 1,
        dielectricMultilayer = 2
    }

    // ---- Requirements ----
    requirement def ReflectivityRequirement {
        subject speculum : Speculum;
        attribute minReflectivity : Reflectance = 0.92;
        require speculum.reflectiveSurface.coating.reflectivity >= minReflectivity;
    }

    requirement def SurfaceSmoothnessRequirement {
        subject surface : ReflectiveSurface;
        attribute maxRoughness : SurfaceRoughness = 0.5;
        require surface.surfaceRoughnessRMS <= maxRoughness;
    }

    requirement def ThermalStabilityRequirement {
        subject substrate : SubstrateBase;
        attribute maxCTE : CoefficientOfThermalExpansion = 5.0e-7;
        require substrate.thermalExpansionCoefficient <= maxCTE;
    }

    requirement def AlignmentAccuracyRequirement {
        subject mount : MountingAssembly;
        attribute minTiltResolution : AngularTilt = 0.001;
        require mount.tiltResolution >= minTiltResolution;
    }

    requirement def ReflectionLawRequirement {
        subject speculum : Speculum;
        require speculum.reflectionAngle == speculum.incidenceAngle;
    }

    // ---- Port Definitions ----
    port def OpticalInputPort {
        in item incomingBeam : LightBeam;
    }

    port def OpticalOutputPort {
        out item reflectedBeam : LightBeam;
    }

    // ---- Part Definitions ----
    part def OpticalCoating {
        attribute coatingType : CoatingType = CoatingType::enhancedAluminum;
        attribute reflectivity : Reflectance = 0.94;
        attribute protectiveOvercoat : Boolean = true;
        attribute thickness : Real = 0.0000001;  // meters
    }

    part def ReflectiveSurface {
        part coating : OpticalCoating;
        attribute surfaceRoughnessRMS : SurfaceRoughness = 0.3;
        attribute surfaceFlatness : Real = 0.063;  // waves at 633 nm
        attribute diameter : Real = 0.0254;  // meters (1 inch)
        attribute clearAperture : Real = 0.022;  // meters

        action def PolishSurface {
            // Action representing final polishing pass
        }
    }

    part def SubstrateBase {
        attribute material : String = "Fused Silica";
        attribute thermalExpansionCoefficient : CoefficientOfThermalExpansion = 5.5e-7;
        attribute operatingTemperatureRange : Temperature[2] = [220.0, 350.0];
        attribute thickness : Real = 0.006;  // meters
        attribute diameter : Real = 0.0254;  // meters
    }

    part def MountingAssembly {
        attribute mountType : String = "Kinematic";
        attribute tiltResolution : AngularTilt = 0.002;
        attribute maxTiltRange : AngularTilt = 4.0;
        attribute lockingMechanism : Boolean = true;

        action def AdjustTilt {
            in tiltX : AngularTilt;
            in tiltY : AngularTilt;
        }

        action def LockPosition {
            // Lock the mount after alignment
        }
    }

    part def Speculum {
        // Ports
        port opticalInput : OpticalInputPort;
        port opticalOutput : OpticalOutputPort;

        // Composite parts
        part reflectiveSurface : ReflectiveSurface;
        part substrate : SubstrateBase;
        part mount : MountingAssembly;

        // Operational attributes
        attribute currentState : OperationalState = OperationalState::standby;
        attribute incidenceAngle : AngularTilt = 45.0;
        attribute reflectionAngle : AngularTilt = 45.0;
        attribute operatingWavelength : Wavelength = 633.0;
        attribute maxOperatingIntensity : OpticalIntensity = 1000.0;

        // Requirements satisfaction
        satisfy ReflectivityRequirement {
            subject = this;
        }
        satisfy ReflectionLawRequirement {
            subject = this;
        }

        // Connections between parts
        connection reflectiveSurfaceToSubstrate connect reflectiveSurface to substrate;
        connection substrateToMount connect substrate to mount;

        // Optical path connection
        connection opticalPath connect opticalInput.incomingBeam to opticalOutput.reflectedBeam;

        // State machine behavior
        state def SpeculumStateMachine {
            entry action initialize {
                // Initialize speculum to standby
            }

            state standby {
                entry action prepareAlignment {
                    mount.AdjustTilt(0.0, 0.0);
                }
                transition standby to active
                    when opticalInput.incomingBeam != null
                    accept LightBeam;
            }

            state active {
                entry action performReflection {
                    // Apply law of reflection
                    reflectionAngle := incidenceAngle;
                    // Beam exits through optical output
                }
                do action reflectBeam {
                    // Continuous reflection while active
                }
                transition active to standby
                    when opticalInput.incomingBeam == null;
            }

            state faulted {
                entry action signalFault {
                    // Indicate fault condition
                }
                transition active to faulted
                    when reflectiveSurface.surfaceRoughnessRMS > 0.5
                    or substrate.thermalExpansionCoefficient > 5.0e-7;
                transition faulted to standby
                    accept ResetSignal;
            }

            transition standby to active
                accept ActivateSignal;

            transition active to standby
                accept DeactivateSignal;
        }

        // Item flow through the speculum
        flow opticalInput.incomingBeam to opticalOutput.reflectedBeam;

        // Main behavior binding
        behavior stateMachine : SpeculumStateMachine;
    }

    // ---- Signal Definitions ----
    item def ActivateSignal;
    item def DeactivateSignal;
    item def ResetSignal;

    // ---- Top-level System ----
    part OpticalInstrument {
        part primarySpeculum : Speculum {
            // Configured instance
            attribute operatingWavelength = 633.0;
            attribute incidenceAngle = 30.0;
        }

        // External light source port
        port lightSourceOutput : OpticalOutputPort;
        port detectorInput : OpticalInputPort;

        connection sourceToSpeculum connect lightSourceOutput.reflectedBeam to primarySpeculum.opticalInput.incomingBeam;
        connection speculumToDetector connect primarySpeculum.opticalOutput.reflectedBeam to detectorInput.incomingBeam;
    }
}
