# Use a small nginx base image
FROM nginx:1.29-alpine

# Remove default nginx index
RUN rm -rf /usr/share/nginx/html/*

# Copy your index.html to nginx html directory
COPY index.html /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Run nginx in foreground (default CMD in nginx image)
CMD ["nginx", "-g", "daemon off;"]