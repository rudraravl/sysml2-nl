package 'Head Mirror System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def ReflectionAngle :> ISQ::PlaneAngleValue {
        doc /* Angle at which light is reflected from mirror surface */
    }
    
    attribute def IlluminationIntensity :> ISQ::LuminousIntensityValue {
        doc /* Intensity of light at target examination area */
    }
    
    attribute def FocalDistance :> ISQ::LengthValue {
        doc /* Working distance from mirror to examination area */
    }
    
    attribute def MirrorDiameter :> ISQ::LengthValue {
        doc /* Diameter of concave reflective surface */
    }
    
    item def LightBeam {
        attribute intensity : IlluminationIntensity;
        attribute direction : ReflectionAngle;
        attribute focalPoint : FocalDistance;
    }
    
    item def AmbientLight {
        attribute sourceIntensity : IlluminationIntensity;
    }
    
    port def LightInputPort {
        in item ambient : AmbientLight;
    }
    
    port def LightOutputPort {
        out item reflected : LightBeam;
    }
    
    port def MechanicalAdjustmentPort {
        attribute angle : ReflectionAngle;
    }
    
    part def ConcaveMirror {
        attribute diameter : MirrorDiameter;
        attribute focalLength : FocalDistance;
        attribute reflectivity : Real;
        
        port lightIn : LightInputPort;
        port lightOut : LightOutputPort;
        
        action reflectAndFocusLight {
            in ambientSource : AmbientLight;
            in mirrorAngle : ReflectionAngle;
            out focusedBeam : LightBeam;
            
            doc /* Reflects and concentrates ambient light into focused beam */
        }
    }
    
    part def PivotJoint {
        attribute verticalRange : ReflectionAngle;
        attribute horizontalRange : ReflectionAngle;
        attribute currentVertical : ReflectionAngle;
        attribute currentHorizontal : ReflectionAngle;
        
        port adjustment : MechanicalAdjustmentPort;
        
        action adjustOrientation {
            in desiredVertical : ReflectionAngle;
            in desiredHorizontal : ReflectionAngle;
            out achievedVertical : ReflectionAngle;
            out achievedHorizontal : ReflectionAngle;
            
            doc /* Enables manual positioning of mirror to direct light */
        }
    }
    
    part def HeadBand {
        attribute circumference : ISQ::LengthValue;
        attribute tension : ISQ::ForceValue;
        attribute material : String;
        
        action secureToHead {
            in headCircumference : ISQ::LengthValue;
            out isSecured : Boolean;
            
            doc /* Fastens device securely to practitioner's forehead */
        }
    }
    
    part def MountingFrame {
        attribute mass : ISQ::MassValue;
        attribute rigidity : Real;
        
        action supportComponents {
            in totalWeight : ISQ::MassValue;
            out stability : Boolean;
            
            doc /* Provides rigid structural support for mirror assembly */
        }
    }
    
    part def HeadMirrorDevice {
        doc /* 
            Medical diagnostic device worn on practitioner's head to reflect 
            and focus ambient light onto patient examination areas, enabling 
            hands-free illumination during medical procedures 
        */
        
        part mirror : ConcaveMirror {
            attribute :>> diameter = 8.0 [SI::cm];
            attribute :>> focalLength = 25.0 [SI::cm];
            attribute :>> reflectivity = 0.92;
        }
        
        part pivot : PivotJoint {
            attribute :>> verticalRange = 90.0 [SI::rad];
            attribute :>> horizontalRange = 60.0 [SI::rad];
            attribute :>> currentVertical = 45.0 [SI::rad];
            attribute :>> currentHorizontal = 0.0 [SI::rad];
        }
        
        part mountFrame : MountingFrame {
            attribute :>> mass = 65.0 [SI::g];
            attribute :>> rigidity = 0.95;
        }
        
        part band : HeadBand {
            attribute :>> circumference = 58.0 [SI::cm];
            attribute :>> tension = 1.8 [SI::N];
            attribute :>> material = "elastic fabric";
        }
        
        port externalLight : LightInputPort;
        port directedLight : LightOutputPort;
        
        connect externalLight to mirror.lightIn;
        connect mirror.lightOut to directedLight;
        
        action illuminateExaminationSite {
            in lightSource : AmbientLight;
            in targetDistance : FocalDistance;
            in targetAngle : ReflectionAngle;
            out illumination : LightBeam;
            
            first start;
            
            then action mountDevice : band.secureToHead {
                in headCircumference = 57.0 [SI::cm];
                out isSecured;
            }
            
            then action stabilize : mountFrame.supportComponents {
                in totalWeight = 50.0 [SI::g];
                out stability;
            }
            
            then action position : pivot.adjustOrientation {
                in desiredVertical = illuminateExaminationSite::targetAngle;
                in desiredHorizontal = 0.0 [SI::rad];
                out achievedVertical;
                out achievedHorizontal;
            }
            
            then action reflect : mirror.reflectAndFocusLight {
                in ambientSource = illuminateExaminationSite::lightSource;
                in mirrorAngle = position.achievedVertical;
                out focusedBeam;
            }
            
            then assign illumination := reflect.focusedBeam;
            then done;
        }
    }
    
    state def DeviceOperationalStates {
        entry; then stored;
        
        state stored {
            doc /* Device is not in use, stored in medical cabinet */
        }
        
        accept PrepareForUse;
        transition stored to mounting;
        
        state mounting {
            doc /* Practitioner is securing device to head */
        }
        
        transition mounting to positioning;
        
        state positioning {
            doc /* Practitioner is adjusting mirror angle for optimal illumination */
        }
        
        transition positioning to operating;
        
        state operating {
            doc /* Device is actively reflecting light during examination */
        }
        
        accept AdjustmentNeeded;
        transition operating to positioning;
        
        accept ExaminationComplete;
        transition operating to stored;
    }
    
    action def PerformExamination {
        in patientArea : String;
        in ambientLightLevel : IlluminationIntensity;
        out examinationQuality : Real;
        
        doc /* Complete medical examination workflow using head mirror illumination */
    }
    
    requirement def IlluminationPerformanceRequirement {
        doc /* Device shall provide adequate focused illumination for medical examination */
        
        require constraint sufficientIntensity {
            doc /* Reflected light intensity shall enable clear visualization of examination area */
        }
        
        require constraint adjustableBeam {
            doc /* Light beam direction shall be adjustable to illuminate target areas */
        }
        
        require constraint stableFocus {
            doc /* Focused beam shall remain stable during examination procedures */
        }
    }
    
    requirement def ErgonomicRequirement {
        doc /* Device shall be comfortable and practical for extended clinical use */
        
        require constraint lightweightConstruction {
            doc /* Total device mass shall not exceed 100 grams */
        }
        
        require constraint comfortableFit {
            doc /* Head band shall distribute pressure evenly without causing discomfort */
        }
        
        require constraint quickAdjustment {
            doc /* Mirror angle shall be adjustable with one hand during procedures */
        }
    }
    
    requirement def ClinicalFunctionalityRequirement {
        doc /* Device shall enable effective hands-free illumination during medical procedures */
        
        require constraint handsFreeoperation {
            doc /* Device shall remain stable without manual support during use */
        }
        
        require constraint adequateWorkingDistance {
            doc /* Focal distance shall accommodate typical examination distances */
        }
    }
    
    requirement <'REQ-001'> primaryFunctionRequirement : IlluminationPerformanceRequirement {
        doc /* 
            The head mirror system shall reflect and focus ambient or external light 
            to illuminate patient examination areas, providing hands-free illumination 
            that enables medical practitioners to perform detailed examinations and 
            minor procedures while keeping both hands available for instruments 
        */
        
        subject device : HeadMirrorDevice;
        
        assume constraint ambientLightPresent {
            doc /* Adequate ambient or supplemental light source is available in examination room */
        }
        
        require constraint sufficientIntensity;
        require constraint adjustableBeam;
        require constraint stableFocus;
    }
    
    requirement <'REQ-002'> ergonomicRequirement : ErgonomicRequirement {
        doc /* Device shall support extended wear during clinical sessions */
        
        subject device : HeadMirrorDevice;
        
        require constraint lightweightConstruction;
        require constraint comfortableFit;
        require constraint quickAdjustment;
    }
    
    requirement <'REQ-003'> functionalRequirement : ClinicalFunctionalityRequirement {
        doc /* Device shall integrate seamlessly into clinical examination workflow */
        
        subject device : HeadMirrorDevice;
        
        require constraint handsFreeoperation;
        require constraint adequateWorkingDistance;
    }
    
    part clinicalHeadMirror : HeadMirrorDevice {
        perform action examinePatient : PerformExamination {
            in patientArea = "throat";
            in ambientLightLevel = 600.0 [SI::cd];
            out examinationQuality;
            
            first start;
            
            then action setupIllumination : illuminateExaminationSite {
                in lightSource {
                    attribute :>> sourceIntensity = 600.0 [SI::cd];
                }
                in targetDistance = 30.0 [SI::cm];
                in targetAngle = 45.0 [SI::rad];
                out illumination;
            }
            
            then action conductExamination {
                doc /* Perform detailed visual examination of illuminated area */
            }
            
            then assign examinationQuality := 0.95;
            then done;
        }
    }
}
