#version 330

uniform vec4 eye;
uniform vec4 ambient;
uniform vec4[20] objects;
uniform vec4[20] objColors;
uniform vec4[10] lightsDirection;
uniform vec4[10] lightsIntensity;
uniform vec4[10] lightsPosition;
uniform ivec4 sizes;

uniform vec4 move;
uniform float zoom;

in vec3 position0;
in vec3 normal0;


//quries:
bool isPlane(vec4 object){
    return object[3] <= 0;
}

bool isSphere(vec4 object){
    return object[3] > 0;
}

bool isSpotlight(vec4 light){
    return light[3] == 1.0;
}

bool isInAngle(vec3 sourcePoint, int lightIndex){
    vec3 lightDirection = lightsDirection[lightIndex].xyz;
    vec3 lightToObject = sourcePoint - lightsPosition[lightIndex].xyz;
    float cosTheta = dot(lightDirection, lightToObject) / dot(normalize(lightDirection), normalize(lightToObject));
    return cosTheta >= lightsPosition[lightIndex].w;
}


//helper methods:
vec3 getObjectNormal(int objectIndex, vec3 sourcePoint){
    if(isPlane(objects[objectIndex])){
        return normalize(objects[objectIndex].xyz);
    }
    vec4 sphere = objects[objectIndex];
    return -normalize( sourcePoint - objects[objectIndex].xyz);
}


vec3 findPointOnPlane(vec4 plane){
    if(plane[0] != 0){
        return vec3(-plane[3]/plane[0], 0, 0);
    }else if(plane[1] != 0){
        return vec3(0, -plane[3]/plane[1], 0);
    }
    return vec3(0, 0, -plane[3]/plane[2]);
}


//Find intersections
float calulateSphereIntersection(vec4 sphere, vec3 sourcePoint, vec3 v){
    float t;
    vec3 sphereCenter = sphere.xyz;
    vec3 L = sphereCenter - sourcePoint;
    float tm = dot(L,v);
    float d = sqrt(dot(L,L) - tm*tm);
    float r = sphere[3];
    if(d > r){
        return -1.0;
    }
    if(tm >= 0){
        t = tm - sqrt(r*r - d*d);
    }else{
        t = tm + sqrt(r*r - d*d);
    }
    return t;
}

float calulatePlaneIntersection(vec4 plane, vec3 sourcePoint, vec3 v){
    vec3 n = normalize(plane.xyz);
    vec3 p0o = -plane.w*n/length(plane.xyz) - sourcePoint;
    float t = dot(n,p0o)/dot(n,v);
    if(t < 0){
        return -1.0;
    }
    return t;
}


vec2 intersection(int objectIndex ,vec3 sourcePoint, vec3 v){
    float min_t = 1.0e10;
    int object_i = -1;
    float t = 0;
    for(int i = 0 ; i < sizes.x ; i++){
        if(i == objectIndex){
            continue;
        }
        if(isSphere(objects[i])){
            t = calulateSphereIntersection(objects[i], sourcePoint, v);
        }else{
            t = calulatePlaneIntersection(objects[i], sourcePoint, v);
        }

        if(t>0 && t <= min_t){
            min_t = t;
            object_i = i;
        }
    }
    return vec2(min_t, object_i);

}



bool isObjectBlocked(vec3 sourcePoint, vec3 lightPos, int objectIndex){
    vec3 v = lightPos - sourcePoint;
    float distToLight = sqrt(dot(v, v));
    vec2 t = intersection(objectIndex, sourcePoint, v);
    if(t[0] == 0){
        return false;
    }
    vec3 intersectionPoint = sourcePoint + t[0] * v;
    vec3 vecToIntersectionPoint = intersectionPoint-sourcePoint;
    float distToIntersectionPoint = sqrt(dot(vecToIntersectionPoint, vecToIntersectionPoint));

    return distToIntersectionPoint < distToLight;
}

bool inSpolight(vec3 sourcePoint, int objectIndex, int lightIndex){
    return !(isObjectBlocked(sourcePoint, lightsPosition[lightIndex].xyz, objectIndex)) && isInAngle(sourcePoint, lightIndex);
}

vec3 calcDiffuseLight(vec3 sourcePoint, int objectIndex, int lightIndex, vec3 v){
    vec3 N = getObjectNormal(objectIndex, sourcePoint);
    vec3 L = normalize(lightsDirection[lightIndex].xyz);
    float k_s = 1;
    if(isPlane(objects[objectIndex]) && (((mod(int(1.5*sourcePoint.x),2) == mod(int(1.5*sourcePoint.y),2)) && ((sourcePoint.x>0 && sourcePoint.y>0) || (sourcePoint.x<0 && sourcePoint.y<0))) || ((mod(int(1.5*sourcePoint.x),2) != mod(int(1.5*sourcePoint.y),2) && ((sourcePoint.x<0 && sourcePoint.y>0) || (sourcePoint.x>0 && sourcePoint.y<0)))))){
        k_s = 0.5;
    }
    return clamp(k_s * objColors[objectIndex].rgb * dot(N, v) * lightsIntensity[lightIndex].rgb,0,1);
}

vec3 calcSpecularLight(vec3 sourcePoint, int objectIndex, int lightIndex, vec3 v){
    float k_s = 0.7;
    vec3 N = getObjectNormal(objectIndex, sourcePoint);
    vec3 lightDirection = lightsDirection[lightIndex].xyz;
    vec3 R = normalize(reflect(v, N));
    float power = objColors[objectIndex].w;

    return clamp(k_s * pow(dot(v, R), power) * lightsIntensity[lightIndex].rgb,0,1);

}


vec3 calcSpotlightEfect(vec3 sourcePoint, int objectIndex, int lightIndex, vec3 v){
    if(inSpolight(sourcePoint, objectIndex, lightIndex)){
        return calcDiffuseLight(sourcePoint, objectIndex, lightIndex, v) + calcSpecularLight(sourcePoint, objectIndex, lightIndex, v);
    }
    return vec3(0, 0, 0);
}

vec3 calcDirectionallightEfect(vec3 sourcePoint, int objectIndex, int lightIndex, vec3 v){
    vec2 t = intersection(objectIndex, sourcePoint, -normalize(lightsDirection[lightIndex].xyz));
    if(t[1] != -1){
        return vec3(0, 0, 0);
    }
    vec3 dist = sourcePoint - position0;
    vec3 lightDir = lightsDirection[lightIndex].xyz;
    vec3 Il = lightsIntensity[lightIndex].xyz * dot(dist,lightDir);
    return  calcDiffuseLight(sourcePoint, objectIndex, lightIndex, v) + calcSpecularLight(sourcePoint, objectIndex, lightIndex, v);

}

vec3 calculateLights(vec3 sourcePoint, int objectIndex, vec3 v){
    vec3 color = ambient.rgb * objColors[objectIndex].rgb;
    for(int i = 0; i < sizes[1]; i++){
        if(isSpotlight(lightsDirection[i])){
            color += calcSpotlightEfect(sourcePoint, objectIndex, i, v);
        }else{
            color += calcDirectionallightEfect(sourcePoint, objectIndex, i, v);
        }
    }
    return color;
}


void main(){

    vec3 v = normalize( position0  - eye.xyz);
    vec2 t = intersection(-1, position0 ,v);
    vec3 sourcePoint = position0 + t.x * v;
    if(t.y < 0){
        discard;
    }else{
        int rep = 5;
        vec3 point = sourcePoint;
        vec3 n;
        while(rep > 0 && t.y < sizes.z-1){
            n = getObjectNormal(int(t.y), point);
            v = normalize(reflect(v,n));
            t = intersection(int(t.y), point, v);
            rep--;
            point = point + t.x * v;
        }


        gl_FragColor = vec4(calculateLights(point, int(t.y), v),1);
    }
}
 


