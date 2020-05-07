# SoulmangaAdmin
Soul Manga Admin

# Docker

- 构建镜像

```
docker build -t soulmangaadmin .
```
- 运行容器

```
# simply run the container instance & bind the port
docker run --name vapor-server -p 8080:8080 soulmangaadmin

# run the instance, bind the port, see logs remove after exit (CTRL+C)
docker run --rm -p 8080:8080 -it soulmangaadmin

# volumes
docker run --rm --name vapor-server \
    --volume "$(pwd):/src" \
    --workdir "/src" \
    -p 8080:8080 \
    soulmangaadmin
```

- 测试容器

```
docker run --rm --name vapor-server \
    --volume "$(pwd):/src" \
    --workdir "/src" \
    -p 8080:8080 \
    -it \
    vapor/swift:5.2
```

## env

- Email 测试

```
https://mailtrap.io/
```

- development

```
cp .env .env.development
```

- production

```
cp .env .env.production
```