package OpticalSpeculum {
    private import ScalarValues::*;

    attribute def WavelengthValue :> Real {
        doc
        /* Optical wavelength in nanometres. */
    }
    attribute def PowerValue :> Real {
        doc
        /* Optical beam power in watts. */
    }
    attribute def ReflectanceValue :> Real {
        doc
        /* Reflectance as a dimensionless fraction in the range [0, 1]. */
    }
    attribute def RoughnessValue :> Real {
        doc
        /* Root-mean-square surface roughness in nanometres. */
    }
    attribute def AngleValue :> Real {
        doc
        /* Plane angle in degrees, measured from the surface normal. */
    }
    attribute def TemperatureValue :> Real {
        doc
        /* Absolute temperature in kelvin. */
    }
    attribute def ExpansionCoeffValue :> Real {
        doc
        /* Linear coefficient of thermal expansion in per kelvin (K^-1). */
    }
    attribute def LengthValue :> Real {
        doc
        /* Linear dimension in millimetres. */
    }

    enum def Polarization {
        linear;
        circular;
        elliptical;
        unpolarized;
    }

    enum def CoatingType {
        enhancedAluminum;
        protectedSilver;
        dielectric;
    }

    attribute def Activate;
    attribute def Deactivate;

    item def LightBeam {
        attribute wavelength : WavelengthValue[1];
        attribute power : PowerValue[1];
        attribute polarization : Polarization[1] default Polarization::unpolarized;
        attribute incidenceAngle : AngleValue[1];
    }

    item def ReflectedBeam :> LightBeam {
        attribute reflectionAngle : AngleValue[1];
    }

    item def OpticalCoating {
        attribute coatingType : CoatingType[1] default CoatingType::enhancedAluminum;
        attribute reflectivity : ReflectanceValue[1] default 0.92;
        attribute hasProtectiveOvercoat : Boolean[1] default true;
    }

    item def SubstrateMaterial {
        attribute materialName : String[1] default "fused silica";
        attribute thermalExpansionCoeff : ExpansionCoeffValue[1] default 0.55e-6;
    }

    port def OpticalInputPort {
        in beam : LightBeam;
    }

    port def OpticalOutputPort {
        out beam : ReflectedBeam;
    }

    action def AlignMirror {
        doc
        /* Adjust the kinematic mount to align the mirror normal with the desired optical axis. */
    }

    action def ReflectBeam {
        doc
        /* Perform specular reflection of the incoming light beam off the polished reflective surface. */
        in inputBeam : LightBeam;
        out outputBeam : ReflectedBeam;
    }

    part def ReflectiveSurface {
        doc
        /* Polished reflective surface with optical coating. */
        attribute roughness : RoughnessValue[1] default 1.0;
        item coating : OpticalCoating[1];
        port surfaceIn : OpticalInputPort;
        port surfaceOut : OpticalOutputPort;
    }

    part def SubstrateBase {
        doc
        /* Stable substrate providing structural support with low thermal expansion. */
        item material : SubstrateMaterial[1];
        attribute operatingTemperature : TemperatureValue[1] default 293.15;
        attribute diameter : LengthValue[1] default 50.0;
        attribute thickness : LengthValue[1] default 10.0;
    }

    part def MountingAssembly {
        doc
        /* Adjustable kinematic mount for precise and stable alignment. */
        attribute mountType : String[1] default "kinematic";
        attribute alignmentPrecision : AngleValue[1] default 0.001;
        attribute numberOfAdjustmentPoints : Integer[1] default 3;
    }

    part def Speculum {
        doc
        /* A high-precision optical mirror (speculum) that redirects a light beam by specular reflection. */

        port opticalInput : OpticalInputPort;
        port opticalOutput : OpticalOutputPort;

        part reflectiveSurface : ReflectiveSurface;
        part substrateBase : SubstrateBase;
        part mountingAssembly : MountingAssembly;

        connection inLink connect opticalInput to reflectiveSurface.surfaceIn;
        connection outLink connect reflectiveSurface.surfaceOut to opticalOutput;

        assert constraint lawOfReflection {
            doc
            /* The angle of reflection equals the angle of incidence. */
            opticalInput.beam.incidenceAngle == opticalOutput.beam.reflectionAngle
        }

        state speculumState {
            entry; then Standby;
            state Standby {
                do action alignMirror : AlignMirror;
            }
            state Active {
                do action reflectBeam : ReflectBeam;
            }
            transition first Standby accept Activate then Active;
            transition first Active accept Deactivate then Standby;
        }
    }

    requirement def HighReflectivityRequirement {
        doc
        /* The reflective coating shall provide reflectivity greater than 92 percent. */
        subject speculum : Speculum;
        constraint {
            speculum.reflectiveSurface.coating.reflectivity >= 0.92
        }
    }

    requirement def LowScatteringRequirement {
        doc
        /* The reflective surface roughness shall not exceed 1 nm RMS to minimize light scattering. */
        subject speculum : Speculum;
        constraint {
            speculum.reflectiveSurface.roughness <= 1.0
        }
    }

    requirement def ThermalStabilityRequirement {
        doc
        /* The substrate material shall have a low coefficient of thermal expansion to maintain figure accuracy. */
        subject speculum : Speculum;
        constraint {
            speculum.substrateBase.material.thermalExpansionCoeff <= 0.6e-6
        }
    }

    requirement def AlignmentPrecisionRequirement {
        doc
        /* The mounting assembly shall provide alignment precision of 0.001 degrees or better. */
        subject speculum : Speculum;
        constraint {
            speculum.mountingAssembly.alignmentPrecision <= 0.001
        }
    }

    requirement def SpecularReflectionRequirement {
        doc
        /* The mirror shall redirect light according to the law of reflection. */
        subject speculum : Speculum;
        constraint {
            speculum.opticalInput.beam.incidenceAngle == speculum.opticalOutput.beam.reflectionAngle
        }
    }

    part speculumUnit : Speculum {
        doc
        /* A specific high-precision speculum configuration for a scientific imaging telescope. */
        part redefines reflectiveSurface {
            attribute redefines roughness = 0.5;
            item redefines coating {
                attribute redefines coatingType = CoatingType::enhancedAluminum;
                attribute redefines reflectivity = 0.96;
                attribute redefines hasProtectiveOvercoat = true;
            }
        }
        part redefines substrateBase {
            item redefines material {
                attribute redefines materialName = "fused silica";
                attribute redefines thermalExpansionCoeff = 0.55e-6;
            }
            attribute redefines operatingTemperature = 293.15;
        }
        part redefines mountingAssembly {
            attribute redefines mountType = "kinematic";
            attribute redefines alignmentPrecision = 0.0005;
            attribute redefines numberOfAdjustmentPoints = 3;
        }
    }

    requirement highReflectivity : HighReflectivityRequirement;
    requirement lowScattering : LowScatteringRequirement;
    requirement thermalStability : ThermalStabilityRequirement;
    requirement alignmentPrecision : AlignmentPrecisionRequirement;
    requirement specularReflection : SpecularReflectionRequirement;

    satisfy highReflectivity by speculumUnit;
    satisfy lowScattering by speculumUnit;
    satisfy thermalStability by speculumUnit;
    satisfy alignmentPrecision by speculumUnit;
    satisfy specularReflection by speculumUnit;
}
