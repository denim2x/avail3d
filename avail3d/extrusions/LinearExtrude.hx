package avail3d.extrusions;

import away3d.bounds.BoundingVolumeBase;
import away3d.core.base.data.UV;
import away3d.core.base.data.Vertex;
import away3d.core.base.Geometry;
import away3d.core.base.SubGeometry;
import away3d.core.base.SubMesh;
import away3d.extrusions.data.FourPoints;
import away3d.extrusions.data.Line;
import away3d.extrusions.data.RenderSide;
import away3d.extrusions.data.SubGeometryList;
import away3d.materials.MaterialBase;
import away3d.materials.utils.MultipleMaterials;
import away3d.tools.helpers.MeshHelper;

import openfl.errors.Error;
import openfl.geom.Point;
import openfl.geom.Vector3D;
import openfl.Vector;

import Reflect;
import avail3d.entities.Mesh;


class LinearExtrude extends Mesh {
  public var axis(get, set): String;
  public var materials(get, set): MultipleMaterials;
  public var subdivision(get, set): Int;
  public var coverAll(get, set): Bool;
  public var flip(get, set): Bool;
  public var centerMesh(get, set): Bool;
  public var thickness(get, set): Float;
  public var thicknessSubdivision(get, set): Int;
  public var ignoreSides(get, set): String;

  inline static public var X_AXIS: String = "x";
  inline static public var Y_AXIS: String = "y";
  inline static public var Z_AXIS: String = "z";

  private var LIMIT: Int;
  private var EPS: Float;

  private var _varr: Vector<Vertex>;
  private var _varr2: Vector<Vertex>;
  private var _uvarr: Vector<UV>;
  private var _subdivision: Int;
  private var _coverAll: Bool;
  private var _flip: Bool;
  private var _closePath: Bool;
  private var _axis: String;
  private var _offset: Float;
  private var _materials: MultipleMaterials;
  private var _activeMaterial: MaterialBase;
  private var _centerMesh: Bool;
  private var _thickness: Float;
  private var _thicknessSubdivision: Int;
  private var _ignoreSides: String;
  
  private var _geomDirty: Bool;
  private var _subGeometry: SubGeometry;
  private var _MaterialsSubGeometries: Vector<SubGeometryList>;

  private var _uva: UV;
  private var _uvb: UV;
  private var _uvc: UV;
  private var _uvd: UV;
  
  private var _maxIndProfile: Int;
  private var _uvs: Vector<Float>;
  private var _vertices: Vector<Float>;
  private var _indices: Vector<UInt>;
  private var _aVectors: Array<Vector3D>;

  private var _baseMax: Float;
  private var _baseMin: Float;

/**
 * Class LinearExtrusion generates walls like meshes with or without thickness from a series of Vector3D's
 * @param  material [optional] MaterialBase. The mesh material - must be set <em>before</em> rendering.
 * @param vectors [optional] Array.&lt;Vector3D&gt;. Vector3D array of profile information to be repeated/rotated 
 *   around some axis.
 * @param axis [optional] String. The axis along which to perform extrusion: X_AXIS, Y_AXIS or Z_AXIS;
 *   default: Y_AXIS.
 * @param offset [optional] Number. The extrusion offset along the axis.
 * @param subdivision [optional] uint. The subdivision of geometry between 2 Vector3D instances;
 *   default: 32.
 * @param coverAll [optional] Boolean. Specifies how UV mapping is to be spreaded across the shape - 
 *   covers an entire side of geometry when true, per segments otherwise; default: false.
 * @param thickness [optional] Number. The simulated thickness; default: 0.
 * @param thicknessSubdivision [optional] uint. When thickness &gt; 0 specifies subdivision of thickness 
 *   (top, left, right, bottom); default: 3.
 * @param materials [optional] MultipleMaterials. Enables multiple materials when thickness &gt; 1; default: null.
 * @param centerMesh [optional] Boolean. When true the geometry is recentered in its object space -
 *   in worldspace if the position after generation is '0,0,0'; default: false.
 * @param closePath [optional] Boolean. Specifies whether the last Vector3D must be linked to the first; 
 *   default: false.
 * @param ignoreSides [optional] String. Prevents the generation of sides if thickness &gt; 0 - options: 
 *   bottom, top, left, right, front, back; default: "".
 * @param flip [optional] Boolean. Reverses the faces depending on the orientations of the Vector3D instances;
 *   default: false.
 */
  public function new(
    material: MaterialBase = null, 
    vectors: Array<Vector3D> = null, 
    axis: String = LinearExtrude.Y_AXIS, 
    offset: Float = 10, 
    subdivision: Int = 1, 
    coverAll: Bool = false, 
    thickness: Float = 0, 
    thicknessSubdivision: Int = 3, 
    materials: MultipleMaterials = null, 
    centerMesh: Bool = false, 
    closePath: Bool = false, 
    ignoreSides: String = "", 
    flip: Bool = false
  ) {
    LIMIT = 196605;
    EPS = .0001;
    _geomDirty = true;
    var geom: Geometry = new Geometry();
    _subGeometry = new SubGeometry();
    
    if (material == null && materials != null && materials.front != null) { 
      material = materials.front;
    }
    super(geom, material);

    _aVectors = vectors;
    _axis = axis;
    _offset = offset;
    _coverAll = coverAll;
    _flip = flip;
    _centerMesh = centerMesh;
    _thickness = Math.abs(thickness);
    this.subdivision = subdivision;
    this.thicknessSubdivision = thicknessSubdivision;
    _ignoreSides = ignoreSides;
    _closePath = closePath;
    
    if (materials != null) this.materials = materials;
    if (_closePath && ignoreSides != "") this.ignoreSides = ignoreSides;
  }

  private function buildExtrude(): Void {
    if (_aVectors == null || _aVectors.length < 2) {
      throw new Error("LinearExtrusion error: at least 2 vector3D required!");
    }

    if (_closePath) {
      _aVectors.push(new Vector3D(_aVectors[0].x, _aVectors[0].y, _aVectors[0].z));
    }

    _maxIndProfile = _aVectors.length * 9;
    _MaterialsSubGeometries = null;
    _geomDirty = false;
    initHolders();
    generate();

    if (_vertices.length > 0) {
      _subGeometry.updateVertexData(_vertices);
      _subGeometry.updateIndexData(_indices);
      _subGeometry.updateUVData(_uvs);
      this.geometry.addSubGeometry(_subGeometry);
    }

    if (_MaterialsSubGeometries != null && _MaterialsSubGeometries.length > 0) {
      var sglist: SubGeometryList;
      var sg: SubGeometry;

      for (i in 1..._MaterialsSubGeometries.length) {
        sglist = _MaterialsSubGeometries[i];
        sg = sglist.subGeometry;
        if (sg != null && sglist.vertices.length > 0) {
          this.geometry.addSubGeometry(sg);
          this.subMeshes[this.subMeshes.length - 1].material = sglist.material;
          sg.updateVertexData(sglist.vertices);
          sg.updateIndexData(sglist.indices);
          sg.updateUVData(sglist.uvs);
        }
      }
    }

    if (_centerMesh) {
      MeshHelper.recenter(this);
    }

    _varr = _varr2 = null;
    _uvarr = null;
  }

  /**
	 * Defines the axis used for the extrusion. Defaults to "y".
	 */
  public function get_axis(): String {
    return _axis;
  }

  public function set_axis(val: String): String {
    if (_axis == val) return val;
    _axis = val;
    invalidateGeometry();
    return val;
  }

  /**
	 * An optional MultipleMaterials object that defines left, right, front, back, top and bottom materials to be set on the resulting lathe extrusion.
	 */
  public function get_materials(): MultipleMaterials {
    return _materials;
  }

  public function set_materials(val: MultipleMaterials): MultipleMaterials {
    _materials = val;
    if (_materials.front != null && this.material != _materials.front) this.material = _materials.front;
    invalidateGeometry();
    return val;
  }

  /**
	 * Defines the subdivisions created in the mesh for the total number of revolutions. Defaults to 1, minimum 1.
	 */
  public function get_subdivision(): Int {
    return _subdivision;
  }

  public function set_subdivision(val: Int): Int {
    val = (val < 1) ? 1 : val;
    if (_subdivision == val) return val;
    _subdivision = val;
    invalidateGeometry();
    return val;
  }

  /**
	 * Defines if the texture(s) should be stretched to cover the entire mesh or per step between segments. Defaults to true.
	 */
  public function get_coverAll(): Bool {
    return _coverAll;
  }

  public function set_coverAll(val: Bool): Bool {
    if (_coverAll == val) return val;
    _coverAll = val;
    invalidateGeometry();
    return val;
  }

  /**
	 * Defines if the generated faces should be inversed. Default false.
	 */
  public function get_flip(): Bool {
    return _flip;
  }

  public function set_flip(val: Bool): Bool {
    if (_flip == val) return val;
    _flip = val;
    invalidateGeometry();
    return val;
  }

  /**
	 * Defines whether the mesh is recentered of not after generation
	 */
  public function get_centerMesh(): Bool {
    return _centerMesh;
  }

  public function set_centerMesh(val: Bool): Bool {
    if (_centerMesh == val) return val;
    _centerMesh = val;
    if (_centerMesh && _subGeometry.vertexData.length > 0) MeshHelper.recenter(this)
    else invalidateGeometry();
    return val;
  }

  /**
	 * Defines the _thickness of the resulting lathed geometry. Defaults to 0 (single face).
	 */
  public function get_thickness(): Float {
    return _thickness;
  }

  public function set_thickness(val: Float): Float {
    val = Math.abs(val);
    if (_thickness == val) return val;
    _thickness = val;
    invalidateGeometry();
    return val;
  }

  /**
	 * Defines the subdivision for the top, bottom, right and left if thickness is set higher to 0. Defaults to 1.
	 */
  public function get_thicknessSubdivision(): Int {
    return _thicknessSubdivision;
  }

  public function set_thicknessSubdivision(val: Int): Int {
    val = (val < 3) ? 3 : val;
    if (_thicknessSubdivision == val) {
      return val;
    }

    _thicknessSubdivision = val;
    invalidateGeometry();
    return val;
  }

  /**
	 * Defines if the top, bottom, left, right, front or back of the the extrusion is left open.
	 */
  public function get_ignoreSides(): String {
    return _ignoreSides;
  }

  public function set_ignoreSides(val: String): String {
    _ignoreSides = val;

    if (_closePath) {
      if (_ignoreSides.indexOf("left") == -1) {
        _ignoreSides += "left,";
      }

      if (_ignoreSides.indexOf("right") == -1) {
        _ignoreSides += "right";
      }
    }

    invalidateGeometry();
    return val;
  }

  /**
	 * @inheritDoc
	 */
  override public function get_bounds(): BoundingVolumeBase {
    if (_geomDirty) {
      buildExtrude();
    }

    return super.bounds;
  }

  /**
	 * @inheritDoc
	 */
  override public function get_geometry(): Geometry {
    if (_geomDirty) {
      buildExtrude();
    }

    return super.geometry;
  }

  /**
	 * @inheritDoc
	 */
  override public function get_subMeshes(): Vector<SubMesh> {
    if (_geomDirty) {
      buildExtrude();
    }

    return super.subMeshes;
  }

  private function addFace(
    v0: Vertex, v1: Vertex, v2: Vertex, uv0: UV, uv1: UV, uv2: UV, mat: MaterialBase, invertU: Bool = false
  ): Void {
    var subGeom: SubGeometry;
    var uvs: Vector<Float>;
    var vertices: Vector<Float>;
    var indices: Vector<UInt>;
    var sglist: SubGeometryList;

    if (_activeMaterial != mat && _materials != null) {
      sglist = getSubGeometryListFromMaterial(mat);
      _subGeometry = subGeom = sglist.subGeometry;
      _uvs = uvs = sglist.uvs;
      _vertices = vertices = sglist.vertices;
      _indices = indices = sglist.indices;

    } else {
      subGeom = _subGeometry;
      uvs = _uvs;
      vertices = _vertices;
      indices = _indices;
    }

    if (vertices.length + 9 > LIMIT) {
      subGeom.updateVertexData(vertices);
      subGeom.updateIndexData(indices);
      subGeom.updateUVData(uvs);
      this.geometry.addSubGeometry(subGeom);
      this.subMeshes[this.subMeshes.length - 1].material = mat;

      subGeom = new SubGeometry();
      subGeom.autoDeriveVertexTangents = true;
      subGeom.autoDeriveVertexNormals = true;

      if (_MaterialsSubGeometries != null && _MaterialsSubGeometries.length > 1) {
        sglist = getSubGeometryListFromMaterial(mat);
        sglist.subGeometry = _subGeometry = subGeom;
        sglist.uvs = _uvs = uvs = new Vector<Float>();
        sglist.vertices = _vertices = vertices = new Vector<Float>();
        sglist.indices = _indices = indices = new Vector<UInt>();

      } else {
        _subGeometry = subGeom;
        uvs = _uvs = new Vector<Float>();
        vertices = _vertices = new Vector<Float>();
        indices = _indices = new Vector<UInt>();
      }
    }

    var ind: Int = Std.int(vertices.length / 3);
    if (invertU) {
      uvs.push(1 - uv0.u);
      uvs.push(uv0.v);
      uvs.push(1 - uv1.u);
      uvs.push(uv1.v);
      uvs.push(1 - uv2.u);
      uvs.push(uv2.v);
    } else {

      uvs.push(uv0.u);
      uvs.push(uv0.v);
      uvs.push(uv1.u);
      uvs.push(uv1.v);
      uvs.push(uv2.u);
      uvs.push(uv2.v);
    }

    vertices.push(v0.x);
    vertices.push(v0.y);
    vertices.push(v0.z);
    vertices.push(v1.x);
    vertices.push(v1.y);
    vertices.push(v1.z);
    vertices.push(v2.x);
    vertices.push(v2.y);
    vertices.push(v2.z);

    indices.push(ind);
    indices.push(ind + 1);
    indices.push(ind + 2);
  }

  private function generate(): Void {
    var v1a: Vertex;
    var v1b: Vertex;
    var v1c: Vertex;
    var v2a: Vertex;
    var v2b: Vertex;
    var v2c: Vertex;
    var v3a: Vertex;
    var v3b: Vertex;
    var v3c: Vertex;
    var v4b: Vertex;
    var v4c: Vertex;

    var baseMaxX: Float = _aVectors[0].x;
    var baseMinX: Float = _aVectors[0].x;
    var baseMaxY: Float = _aVectors[0].y;
    var baseMinY: Float = _aVectors[0].y;
    var baseMaxZ: Float = _aVectors[0].z;
    var baseMinZ: Float = _aVectors[0].z;

    for (i in 0..._aVectors.length) {
      baseMaxX = Math.max(_aVectors[i].x, baseMaxX);
      baseMinX = Math.min(_aVectors[i].x, baseMinX);
      baseMaxY = Math.max(_aVectors[i].y, baseMaxY);
      baseMinY = Math.min(_aVectors[i].y, baseMinY);
      baseMaxZ = Math.max(_aVectors[i].z, baseMaxZ);
      baseMinZ = Math.min(_aVectors[i].z, baseMinZ);
    }

    var offset: Float = 0;
    switch(_axis) {
      case LinearExtrude.X_AXIS: 
        _baseMax = Math.abs(baseMaxX) - Math.abs(baseMinX);
        if (baseMinZ > 0 && baseMaxZ > 0) {
          _baseMin = baseMaxZ - baseMinZ;
          offset = -baseMinZ;

        } else if (baseMinZ < 0 && baseMaxZ < 0) {
          _baseMin = Math.abs(baseMinZ - baseMaxZ);
          offset = -baseMinZ;

        } else {
          _baseMin = Math.abs(baseMaxZ) + Math.abs(baseMinZ);
          offset = Math.abs(baseMinZ) + ((baseMaxZ < 0) ? -baseMaxZ : 0);
        }

      case LinearExtrude.Y_AXIS: 
        _baseMax = Math.abs(baseMaxY) - Math.abs(baseMinY);
        if (baseMinX > 0 && baseMaxX > 0) {
          _baseMin = baseMaxX - baseMinX;
          offset = -baseMinX;

        } else if (baseMinX < 0 && baseMaxX < 0) {
          _baseMin = Math.abs(baseMinX - baseMaxX);
          offset = -baseMinX;

        } else {
          _baseMin = Math.abs(baseMaxX) + Math.abs(baseMinX);
          offset = Math.abs(baseMinX) + ((baseMaxX < 0) ? -baseMaxX : 0);
        }

      case LinearExtrude.Z_AXIS: 
        _baseMax = Math.abs(baseMaxZ) - Math.abs(baseMinZ);
        if (baseMinY > 0 && baseMaxY > 0) {
          _baseMin = baseMaxY - baseMinY;
          offset = -baseMinY;

        } else if (baseMinY < 0 && baseMaxY < 0) {
          _baseMin = Math.abs(baseMinY - baseMaxY);
          offset = -baseMinY;

        } else {
          _baseMin = Math.abs(baseMaxY) + Math.abs(baseMinY);
          offset = Math.abs(baseMinY) + ((baseMaxY < 0) ? -baseMaxY : 0);
        }
    }

    var aLines: Array<FourPoints>;
    var prop1: String = "";
    var prop2: String = "";
    var prop3: String = "";
    var vector: Vertex = new Vertex();
    var renderSide: RenderSide = null;
    var increase: Float = _offset / _subdivision;

    if (_thickness != 0) {
      var aListsides: Array<String> = ["top", "bottom", "right", "left", "front", "back"];
      renderSide = new RenderSide();

      for (side in aListsides) {
        Reflect.setProperty(renderSide, side, _ignoreSides.indexOf(side) == -1);
      }

      switch(_axis) {
        case LinearExtrude.X_AXIS: 
          prop1 = Z_AXIS;
          prop2 = Y_AXIS;
          prop3 = X_AXIS;

        case LinearExtrude.Y_AXIS: 
          prop1 = X_AXIS;
          prop2 = Z_AXIS;
          prop3 = Y_AXIS;

        case LinearExtrude.Z_AXIS: 
          prop1 = Y_AXIS;
          prop2 = X_AXIS;
          prop3 = Z_AXIS;
      }

      aLines = buildThicknessPoints(prop1, prop2);

      var points: FourPoints;
      var vector2 = new Vertex();
      var vector3 = new Vertex();
      var vector4 = new Vertex();

      for (i in 0...aLines.length) {
        points = aLines[i];

        if (i == 0) {
          Reflect.setProperty(vector, prop1, points.pt2.x);
          Reflect.setProperty(vector, prop2, points.pt2.y);
          Reflect.setProperty(vector, prop3, Reflect.getProperty(_aVectors[0], prop3));
          _varr.push(new Vertex(vector.x, vector.y, vector.z));

          Reflect.setProperty(vector2, prop1, points.pt1.x);
          Reflect.setProperty(vector2, prop2, points.pt1.y);
          Reflect.setProperty(vector2, prop3, Reflect.getProperty(_aVectors[0], prop3));
          _varr2.push(new Vertex(vector2.x, vector2.y, vector2.z));

          elevate(vector, vector2, increase);

          if (aLines.length == 1) {
            Reflect.setProperty(vector3, prop1, points.pt4.x);
            Reflect.setProperty(vector3, prop2, points.pt4.y);
            Reflect.setProperty(vector3, prop3, Reflect.getProperty(_aVectors[0], prop3));
            _varr.push(new Vertex(vector3.x, vector3.y, vector3.z));

            Reflect.setProperty(vector4, prop1, points.pt3.x);
            Reflect.setProperty(vector4, prop2, points.pt3.y);
            Reflect.setProperty(vector4, prop3, Reflect.getProperty(_aVectors[0], prop3));
            _varr2.push(new Vertex(vector4.x, vector4.y, vector4.z));

            elevate(vector3, vector4, increase);
          }

        } else if (i == aLines.length - 1) {
          Reflect.setProperty(vector, prop1, points.pt2.x);
          Reflect.setProperty(vector, prop2, points.pt2.y);
          Reflect.setProperty(vector, prop3, Reflect.getProperty(_aVectors[i], prop3));
          _varr.push(new Vertex(vector.x, vector.y, vector.z));

          Reflect.setProperty(vector2, prop1, points.pt1.x);
          Reflect.setProperty(vector2, prop2, points.pt1.y);
          Reflect.setProperty(vector2, prop3, Reflect.getProperty(_aVectors[i], prop3));
          _varr2.push(new Vertex(vector2.x, vector2.y, vector2.z));

          elevate(vector, vector2, increase);

          Reflect.setProperty(vector3, prop1, points.pt4.x);
          Reflect.setProperty(vector3, prop2, points.pt4.y);
          Reflect.setProperty(vector3, prop3, Reflect.getProperty(_aVectors[i], prop3));
          _varr.push(new Vertex(vector3.x, vector3.y, vector3.z));

          Reflect.setProperty(vector4, prop1, points.pt3.x);
          Reflect.setProperty(vector4, prop2, points.pt3.y);
          Reflect.setProperty(vector4, prop3, Reflect.getProperty(_aVectors[i], prop3));
          _varr2.push(new Vertex(vector4.x, vector4.y, vector4.z));

          elevate(vector3, vector4, increase);

        } else {
          Reflect.setProperty(vector, prop1, points.pt2.x);
          Reflect.setProperty(vector, prop2, points.pt2.y);
          Reflect.setProperty(vector, prop3, Reflect.getProperty(_aVectors[i], prop3));
          _varr.push(new Vertex(vector.x, vector.y, vector.z));

          Reflect.setProperty(vector2, prop1, points.pt1.x);
          Reflect.setProperty(vector2, prop2, points.pt1.y);
          Reflect.setProperty(vector2, prop3, Reflect.getProperty(_aVectors[i], prop3));
          _varr2.push(new Vertex(vector2.x, vector2.y, vector2.z));

          elevate(vector, vector2, increase);
        }
      }

    } else {
      for (i in 0..._aVectors.length) {
        vector.x = _aVectors[i].x;
        vector.y = _aVectors[i].y;
        vector.z = _aVectors[i].z;
        _varr.push(new Vertex(vector.x, vector.y, vector.z));

        for (j in 0..._subdivision) {
          Reflect.setProperty(vector, "_"+_axis, Reflect.getProperty(vector, _axis) + increase);
          _varr.push(new Vertex(vector.x, vector.y, vector.z));
        }
      }
    }

    var index: Int = 0;
    var mat: MaterialBase;
    if (_thickness > 0) {
      // TODO: What's supposed to be in here ??
    }

    var step: Float = 1 / (_aVectors.length - 1);
    var vindex: Int;

    for (i in 0..._aVectors.length - 1) {
      if (_coverAll) {
        _uva.u = _uvb.u = step * i;
        _uvc.u = _uvd.u = _uvb.u + step;

      } else {
        _uva.u = 0;
        _uvb.u = 0;
        _uvc.u = 1;
        _uvd.u = 1;
      }

      for (j in 0..._subdivision) {
        _uva.v = _uvd.v = 1 - (j / _subdivision);
        _uvb.v = _uvc.v = 1 - (j + 1) / _subdivision;

        vindex = index + j;
        if (_thickness == 0) {
          if (_flip) {
            addFace(
              _varr[vindex + 1], _varr[vindex], _varr[vindex + _subdivision + 2], 
              _uvb, _uva, _uvc, this.material
            );
            addFace(
              _varr[vindex + _subdivision + 2], _varr[vindex], _varr[vindex + _subdivision + 1], 
              _uvc, _uva, _uvd, this.material
            );

          } else {
            addFace(
              _varr[vindex], _varr[vindex + 1], _varr[vindex + _subdivision + 2], 
              _uva, _uvb, _uvc, this.material
            );
            addFace(
              _varr[vindex], _varr[vindex + _subdivision + 2], _varr[vindex + _subdivision + 1], 
              _uva, _uvc, _uvd, this.material
            );
          }

        } else {
          //half side 1
          v1a = _varr[vindex];
          v1b = _varr[vindex + 1];
          v1c = _varr[vindex + _subdivision + 2];
          v2a = _varr[vindex];
          v2b = _varr[vindex + _subdivision + 2];
          v2c = _varr[vindex + _subdivision + 1];

          //half side 2
          v3a = _varr2[vindex];
          v3b = _varr2[vindex + 1];
          v3c = _varr2[vindex + _subdivision + 2];
          v4b = _varr2[vindex + _subdivision + 2];
          v4c = _varr2[vindex + _subdivision + 1];

          //right
          if (renderSide.right) {
            mat = (materials != null && materials.right != null) ? materials.right : this.material;

            if (_flip) {
              addFace(v1a, v1b, v1c, _uva, _uvb, _uvc, mat);
              addFace(v2a, v2b, v2c, _uva, _uvc, _uvd, mat);

            } else {
              addFace(v1b, v1a, v1c, _uvb, _uva, _uvc, mat);
              addFace(v2b, v2a, v2c, _uvc, _uva, _uvd, mat);
            }
          }

          if (renderSide.left) {
            mat = (materials != null && materials.left != null) ? materials.left : this.material;

            if (_flip) {
              addFace(v4c, v3b, v3a, _uvd, _uvb, _uva, mat, true);
              addFace(v4c, v4b, v3b, _uvd, _uvc, _uvb, mat, true);

            } else {
              addFace(v3b, v4c, v3a, _uvb, _uvd, _uva, mat, true);
              addFace(v4b, v4c, v3b, _uvc, _uvd, _uvb, mat, true);
            }
          }

          if (i == 0 && renderSide.back) {
            mat = (materials != null && materials.back != null) ? materials.back : this.material;

            if (_flip) {
              addFace(v3a, v3b, v1b, _uva, _uvb, _uvc, mat);
              addFace(v3a, v1b, v1a, _uva, _uvc, _uvd, mat);

            } else {
              addFace(v3b, v3a, v1b, _uvb, _uva, _uvc, mat);
              addFace(v1b, v3a, v1a, _uvc, _uva, _uvd, mat);
            }
          }

          if (j == 0 && renderSide.bottom) {
            mat = (materials != null && materials.bottom != null) ? materials.bottom : this.material;
            addThicknessSubdivision([v4c, v3a], [v2c, v1a], _uvd.u, _uvb.u, mat);
          }

          if (j == _subdivision - 1 && renderSide.top) {
            mat = (materials != null && materials.top != null) ? materials.top : this.material;
            addThicknessSubdivision([v3b, v3c], [v1b, v1c], _uva.u, _uvc.u, mat);
          }

          if (i == _aVectors.length - 2 && renderSide.front) {
            mat = (materials != null && materials.front != null) ? materials.front : this.material;

            if (_flip) {
              addFace(v2c, v2b, v3c, _uva, _uvb, _uvc, mat);
              addFace(v2c, v3c, v4c, _uva, _uvc, _uvd, mat);

            } else {
              addFace(v2b, v2c, v3c, _uvb, _uva, _uvc, mat);
              addFace(v3c, v2c, v4c, _uvc, _uva, _uvd, mat);
            }
          }
        }
      }

      index += _subdivision + 1;
    }
  }

  private function addThicknessSubdivision(
    points1: Array<Vertex>, points2: Array<Vertex>, u1: Float, u2: Float, mat: MaterialBase
  ): Void {
    var stepx: Float;
    var stepy: Float;
    var stepz: Float;

    var va: Vertex;
    var vb: Vertex;
    var vc: Vertex;
    var vd: Vertex;

    var v1: Float = 0;
    var v2: Float = 0;

    var index: Int = 0;
    var tmp = new Array<Vertex>();

    for (i in 0...points1.length) {
      stepx = (points2[i].x - points1[i].x) / _thicknessSubdivision;
      stepy = (points2[i].y - points1[i].y) / _thicknessSubdivision;
      stepz = (points2[i].z - points1[i].z) / _thicknessSubdivision;
      
      for (j in 0..._thicknessSubdivision + 1) {
        tmp.push(new Vertex(points1[i].x + (stepx * j), points1[i].y + (stepy * j), points1[i].z + (stepz * j)));
      }
    }

    for (i in 0...points1.length - 1) {
      for (j in 0..._thicknessSubdivision) {
        v1 = j / _thicknessSubdivision;
        v2 = (j + 1) / _thicknessSubdivision;

        _uva.u = u1;
        _uva.v = v1;
        _uvb.u = u1;
        _uvb.v = v2;
        _uvc.u = u2;
        _uvc.v = v2;
        _uvd.u = u2;
        _uvd.v = v1;

        va = tmp[index + j];
        vb = tmp[(index + j) + 1];
        vc = tmp[(index + j) + (_thicknessSubdivision + 2)];
        vd = tmp[(index + j) + (_thicknessSubdivision + 1)];

        if (!_flip) {
          addFace(va, vb, vc, _uva, _uvb, _uvc, mat);
          addFace(va, vc, vd, _uva, _uvc, _uvd, mat);

        } else {
          addFace(vb, va, vc, _uvb, _uva, _uvc, mat);
          addFace(vc, va, vd, _uvc, _uva, _uvd, mat);
        }
      }

      index += _subdivision + 1;
    }
  }

  private function elevate(v0: Vertex, v1: Vertex, increase: Float): Void {
    for (i in 0..._subdivision) {
      Reflect.setProperty(v0, _axis, Reflect.getProperty(v0, _axis) + increase);
      Reflect.setProperty(v1, _axis, Reflect.getProperty(v1, _axis) + increase);

      _varr.push(new Vertex(Reflect.getProperty(v0, X_AXIS), Reflect.getProperty(v0, Y_AXIS), Reflect.getProperty(v0, Z_AXIS)));
      _varr2.push(new Vertex(Reflect.getProperty(v1, X_AXIS), Reflect.getProperty(v1, Y_AXIS), Reflect.getProperty(v1, Z_AXIS)));
    }
  }

  private function buildThicknessPoints(prop1: String, prop2: String): Array<FourPoints> {
    var anchors = new Array<FourPoints>();
		var lines = new Array<FourPoints>();
    
    for (i in 0..._aVectors.length - 1) {
      if (Reflect.getProperty(_aVectors[i], prop1) == 0 && Reflect.getProperty(_aVectors[i], prop2) == 0) {
        Reflect.setProperty(_aVectors[i], prop1, EPS);
      }

      if (
        Reflect.getProperty(_aVectors[i + 1], prop2) && 
        Reflect.getProperty(_aVectors[i], prop2) == Reflect.getProperty(_aVectors[i + 1], prop2)
      ) {
        Reflect.setProperty(_aVectors[i + 1], prop2, Reflect.getProperty(_aVectors[i + 1], prop2) + EPS);
      }

      if (
        Reflect.getProperty(_aVectors[i], prop1) && 
        Reflect.getProperty(_aVectors[i], prop1) == Reflect.getProperty(_aVectors[i + 1], prop1)
      ) {
        Reflect.setProperty(_aVectors[i + 1], prop1, Reflect.getProperty(_aVectors[i + 1], prop1) + EPS);
      }

      anchors.push(defineAnchors(_aVectors[i], _aVectors[i + 1], prop1, prop2));
    }

    var len = anchors.length;
    var pointResult: FourPoints;
    if (len > 1) {
      var pt2: FourPoints;
      for (i in 0...len) {
        pt2 = anchors[(i < len) ? (i + 1) : (i - 1)];
        pointResult = definelines(i, anchors[i], pt2, lines);

        if (pointResult != null) {
          lines.push(pointResult);
        }
      }

      return lines;
    }
    
    var fourPoints: FourPoints = new FourPoints();
    var anchorFP: FourPoints = anchors[0];

    fourPoints.pt1 = anchorFP.pt1;
    fourPoints.pt2 = anchorFP.pt2;
    fourPoints.pt3 = anchorFP.pt3;
    fourPoints.pt4 = anchorFP.pt4;

    return [fourPoints];
  }

  private function definelines(
    index: Int, point1: FourPoints, point2: FourPoints = null, lines: Array<FourPoints> = null
  ): FourPoints {
    var tmppt: FourPoints;
    var fourPoints: FourPoints = new FourPoints();

    if (point2 == null) {
      tmppt = lines[index - 1];
      fourPoints.pt1 = tmppt.pt3;
      fourPoints.pt2 = tmppt.pt4;
      fourPoints.pt3 = point1.pt3;
      fourPoints.pt4 = point1.pt4;

      return fourPoints;
    }

    var line1: Line = buildObjectLine(point1.pt1.x, point1.pt1.y, point1.pt3.x, point1.pt3.y);
    var line2: Line = buildObjectLine(point1.pt2.x, point1.pt2.y, point1.pt4.x, point1.pt4.y);
    var line3: Line = buildObjectLine(point2.pt1.x, point2.pt1.y, point2.pt3.x, point2.pt3.y);
    var line4: Line = buildObjectLine(point2.pt2.x, point2.pt2.y, point2.pt4.x, point2.pt4.y);

    var cross1: Point = lineIntersect(line3, line1);
    var cross2: Point = lineIntersect(line2, line4);

    if (cross1 == null || cross2 == null) {
      return null;
    }

    if (index == 0) {
      fourPoints.pt1 = point1.pt1;
      fourPoints.pt2 = point1.pt2;
      fourPoints.pt3 = cross1;
      fourPoints.pt4 = cross2;
      
      return fourPoints;
    }

    tmppt = lines[index - 1];
    fourPoints.pt1 = tmppt.pt3;
    fourPoints.pt2 = tmppt.pt4;
    fourPoints.pt3 = cross1;
    fourPoints.pt4 = cross2;

    return fourPoints;
  }

  private function defineAnchors(base: Vector3D, baseEnd: Vector3D, prop1: String, prop2: String): FourPoints {
    var angle: Float = (Math.atan2(
      Reflect.getProperty(base, prop2) - Reflect.getProperty(baseEnd, prop2), 
      Reflect.getProperty(base, prop1) - Reflect.getProperty(baseEnd, prop1)
    ) * 180) / Math.PI;
    
    angle -= 270;
    var angle2: Float = angle + 180;

    var fourPoints: FourPoints = new FourPoints();
    fourPoints.pt1 = new Point(Reflect.getProperty(base, prop1), Reflect.getProperty(base, prop2));
    fourPoints.pt2 = new Point(Reflect.getProperty(base, prop1), Reflect.getProperty(base, prop2));
    fourPoints.pt3 = new Point(Reflect.getProperty(baseEnd, prop1), Reflect.getProperty(baseEnd, prop2));
    fourPoints.pt4 = new Point(Reflect.getProperty(baseEnd, prop1), Reflect.getProperty(baseEnd, prop2));
    
    var radius: Float = _thickness * .5;
    fourPoints.pt1.x = fourPoints.pt1.x + Math.cos(-angle / 180 * Math.PI) * radius;
    fourPoints.pt1.y = fourPoints.pt1.y + Math.sin(angle / 180 * Math.PI) * radius;
    fourPoints.pt2.x = fourPoints.pt2.x + Math.cos(-angle2 / 180 * Math.PI) * radius;
    fourPoints.pt2.y = fourPoints.pt2.y + Math.sin(angle2 / 180 * Math.PI) * radius;
    fourPoints.pt3.x = fourPoints.pt3.x + Math.cos(-angle / 180 * Math.PI) * radius;
    fourPoints.pt3.y = fourPoints.pt3.y + Math.sin(angle / 180 * Math.PI) * radius;
    fourPoints.pt4.x = fourPoints.pt4.x + Math.cos(-angle2 / 180 * Math.PI) * radius;
    fourPoints.pt4.y = fourPoints.pt4.y + Math.sin(angle2 / 180 * Math.PI) * radius;
    
    return fourPoints;
  }

  private function buildObjectLine(origX: Float, origY: Float, endX: Float, endY: Float): Line {
    var line: Line = new Line();
    line.ax = origX;
    line.ay = origY;
    line.bx = endX - origX;
    line.by = endY - origY;

    return line;
  }

  private function isFinite(ptx: Float): Bool {
    return (Math.NEGATIVE_INFINITY != ptx && Math.POSITIVE_INFINITY != ptx);
  }

  private function lineIntersect(Line1: Line, Line2: Line): Point {
    Line1.bx = (Line1.bx == 0) ? EPS : Line1.bx;
    Line2.bx = (Line2.bx == 0) ? EPS : Line2.bx;

    var a1: Float = Line1.by / Line1.bx;
    var b1: Float = Line1.ay - a1 * Line1.ax;
    var a2: Float = Line2.by / Line2.bx;
    var b2: Float = Line2.ay - a2 * Line2.ax;

    var nzero: Float = (a1 - a2 == 0) ? EPS : a1 - a2;

    var ptx: Float = (b2 - b1) / nzero;
    var pty: Float = a1 * ptx + b1;

    if (isFinite(ptx) && isFinite(pty)) {
      return new Point(ptx, pty);
    } 
    
    trace("infinity");
    return null;
  }

  private function initHolders(): Void {
    if (_uva == null) {
      _uva = new UV(0, 0);
      _uvb = new UV(0, 0);
      _uvc = new UV(0, 0);
      _uvd = new UV(0, 0);
    }

    _varr = new Vector<Vertex>();
    _varr2 = new Vector<Vertex>();
    _uvarr = new Vector<UV>();
    _uvs = new Vector<Float>();
    _vertices = new Vector<Float>();
    _indices = new Vector<UInt>();
    
    if (_materials != null) {
      _MaterialsSubGeometries = new Vector<SubGeometryList>();
      var sglist: SubGeometryList = new SubGeometryList();
      _MaterialsSubGeometries.push(sglist);
      sglist.subGeometry = new SubGeometry();
      _subGeometry = sglist.subGeometry;
      sglist.uvs = _uvs = new Vector<Float>();
      sglist.vertices = _vertices = new Vector<Float>();
      sglist.indices = _indices = new Vector<UInt>();
      sglist.material = this.material;
      if (sglist.material.name == null) {
        sglist.material.name = "baseMaterial";
      }

    } else {
      _subGeometry.autoDeriveVertexNormals = true;
      _subGeometry.autoDeriveVertexTangents = true;
    }
  }

  private function getSubGeometryListFromMaterial(mat: MaterialBase): SubGeometryList {
    var sglist: SubGeometryList = null;
    for (i in 0..._MaterialsSubGeometries.length) {
      if (_MaterialsSubGeometries[i].material == mat) {
        sglist = _MaterialsSubGeometries[i];
        break;
      }
    }

    if (sglist == null) {
      sglist = new SubGeometryList();
      sglist.subGeometry = new SubGeometry();
      sglist.uvs = new Vector<Float>();
      sglist.vertices = new Vector<Float>();
      sglist.indices = new Vector<UInt>();
      sglist.material = mat;

      _MaterialsSubGeometries.push(sglist);
    }

    return sglist;
  }

  /**
	 * Invalidates the geometry, causing it to be rebuilt.
	 */
  private function invalidateGeometry(): Void {
    if (_geomDirty) {
      return;
    }

    _geomDirty = true;
    invalidateBounds();
  }
}
